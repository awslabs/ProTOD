#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

update_schema

function copy_files_to_output_bucket() {
    myzipfile="protod-$timestamp.zip"
    if [[ -v DEBUG ]]; then
        echo "Copying results from staged bucket folder"
        aws s3 sync s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" ./StageFolder ||
            { echo "Error copying files from the staged bucket folder, exiting"; exit_script; }
        cd ./StageFolder || exit_script
        zip "$myzipfile" *
        echo "Sending results to the internal output bucket."
        aws s3 cp ./"$myzipfile" "s3://$JOB_OUTPUT_BUCKET/$operator/" ||
            { echo "Error copying files to the internal output  bucket, exiting"; exit_script; }
    else
        aws s3 sync s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" ./StageFolder ||
            { echo "Error copying files from the staged bucket folder, exiting"; exit_script; }
        cd StageFolder || exit_script
        zip "$myzipfile" *
        aws s3 cp ./"$myzipfile" "s3://$JOB_OUTPUT_BUCKET/$operator/" ||
            { echo "Error copying files to the internal output  bucket, exiting"; exit_script; }
    fi
}

function copy_files_to_staged_output_bucket() {
    if [[ -v DEBUG ]]; then
        echo "Sending results to the output bucket to trigger the Lambda for SNS."
        aws s3 cp ./"$myoutputfile" "s3://$JOB_OUTPUT_BUCKET/StageFolder/$FOLDER/" ||
            { echo "Error copying files to the output bucket, exiting"; exit_script; }
        echo "Done"
    else
        aws s3 cp ./"$myoutputfile" "s3://$JOB_OUTPUT_BUCKET/StageFolder/$FOLDER/" &>/dev/null ||
            { echo "Error copying files to the output bucket, exiting"; exit_script; }
    fi
}

function copy_files_to_external_bucket() {
    myzipfile="protod-$timestamp.zip"
    if [[ -v DEBUG ]]; then
        echo "Sending results from staged bucket folder"
        aws s3 sync s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" ./StageFolder ||
            { echo "Error copying files from the staged bucket folder, exiting"; exit_script; }
        cd ./StageFolder || exit_script
        zip "$myzipfile" *
        echo "Sending results to the external bucket."
        aws s3 cp ./"$myzipfile" "s3://$EXTERNAL_BUCKET/" ||
            { echo "Error copying files to the external bucket, exiting"; exit_script; }
    else
        aws s3 sync s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" ./StageFolder ||
            { echo "Error copying files from the input bucket, exiting"; exit_script; }
        cd StageFolder || exit_script
        zip "$myzipfile" *
        aws s3 cp ./"$myzipfile" "s3://$EXTERNAL_BUCKET/" ||
            { echo "Error copying files to the external bucket, exiting"; exit_script; }
    fi
}

function remove_staged_files_from_output_bucket(){
    if [[ -v DEBUG ]]; then
        echo "Removing staged files from the output bucket."
        aws s3 rm s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" --recursive ||
            { echo "Error removing staged files from the output bucket, exiting"; exit_script; }
    fi
    aws s3 rm s3://"$JOB_OUTPUT_BUCKET"/StageFolder/"$FOLDER" --recursive &>/dev/null ||
        { echo "Error removing staged files from the output bucket, exiting"; exit_script; }
}

function assume_role() {
    if [[ -v DEBUG ]]; then
        echo "This is my role before I assume the S3BucketAccessRole"
        aws sts get-caller-identity --no-cli-pager
        echo "Assuming S3BucketAccessRole"
        if ! TEMP_STS_ASSUMED=$(aws sts assume-role --role-arn "$ROLE_ARN" \
                                                    --external-id "$EXTERNAL_ID" \
                                                    --role-session-name S3BucketAccessRoleSession \
                                                    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]"\
                                                    --output text)
        then
            echo "Unable to assume role"
            exit_script 1
        fi
        export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
                $(echo "$TEMP_STS_ASSUMED"))
        echo "This is my S3BucketAccessRole"
        aws sts get-caller-identity --no-cli-pager
    else
        if ! TEMP_STS_ASSUMED=$(aws sts assume-role --role-arn "$ROLE_ARN" \
                                                    --external-id "$EXTERNAL_ID" \
                                                    --role-session-name S3BucketAccessRoleSession \
                                                    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]"\
                                                    --output text) &>/dev/null
        then
            echo "Unable to assume role"
            exit_script 1
        fi
        export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
                $(echo "$TEMP_STS_ASSUMED"))
    fi
}

function unassume_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
}

function send_data_to_dynamodb() {
    if [[ -v DEBUG ]]; then
        echo "Sending results to SQS to be added to the DynamoDB scan table"
        aws sqs send-message --queue-url "$SQS_QUEUE" --message-body "$JSON" --no-cli-pager ||
            { echo "Error sending data to SQS, exiting"; exit_script; }
        echo "All done!"
    else
        aws sqs send-message --queue-url "$SQS_QUEUE" --message-body "$JSON" --no-cli-pager &>/dev/null ||
            { echo "Error sending data to SQS, exiting"; exit_script; }
        echo "All done!"
    fi
}

function notify_consultant() {
    myzipfile="protod-$timestamp.zip"
    notification_filename="protod-$timestamp-notify.txt"
    echo "The batch job $AWS_BATCH_JOB_ID has completed succesfully" > ./"$notification_filename"
    echo "The output of protod was saved to a file named $myzipfile and sent to an external bucket" >> ./"$notification_filename"
    echo "The owner of the AWS account was notified via email that the file is now available to them." >> ./"$notification_filename"
    if [[ -v DEBUG ]]; then
        echo "Sending notification to the consultant that the file was sent to the external bucket."
        aws s3 cp ./"$notification_filename" "s3://$JOB_OUTPUT_BUCKET/$operator/" ||
            { echo "Error copying notification file to the output bucket, exiting"; exit_script; }
        echo "Done"
    else
        aws s3 cp ./"$notification_filename" "s3://$JOB_OUTPUT_BUCKET/$operator/" &>/dev/null ||
            { echo "Error copying notification file to the output bucket, exiting"; exit_script; }
    fi
}

if [[ ! -v LAST_CONTAINER ]]; then
    copy_files_to_staged_output_bucket
    send_data_to_dynamodb
else
    if [[ -v EXTERNAL_BUCKET ]]; then
        if [[ "$BOTH_BUCKETS" == 0 ]]; then
            assume_role
            copy_files_to_external_bucket
            unassume_role
            copy_files_to_output_bucket
        else
            assume_role
            copy_files_to_external_bucket
            unassume_role
            notify_consultant
        fi
    else
        copy_files_to_output_bucket
        remove_staged_files_from_output_bucket
    fi
fi
