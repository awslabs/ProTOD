#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Optional arguments: --role, --enable, --disable"
    echo "          --role <IAMROLE> : Name of the IAM role to assume"
    echo "          --enable : Enables S3 Lambda notification, Fargate front end, updates Secrets Manager secret."
    echo "          --disable : Disables S3 Lambda notification, Fargate front end, ELB logging"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--role') buildrole=$2 ;;
        '--enable') protod_enable=true ;;
        '--disable') protod_disable=true ;;
        '--help')
            print_help
            return 80 ;;
    esac
    shift
done

# Assume role, if specified
if [[ -n $buildrole ]]; then
    . ./assume-role.sh --role "$buildrole"
    if [[ $? != 0 ]]; then
        echo "<ERROR::update-infra.sh> ./scripts/assume-role.sh did not succeed."
        return 80
    fi
fi

# Determine if build is being executed by CodeBuild
if [[ -n $CODEBUILD_BUILD_ARN ]]; then
    CODEBUILD_DEPLOY=true
else
    CODEBUILD_DEPLOY=false
fi


if [[ $protod_enable == true ]]; then
    protod_enable=""
    echo "<INFO::update-infra.sh> Enabling ProTOD infrastructure"

    # Enable Amazon Inspector, Security Hub, and GuardDuty
    echo "<INFO::update-infra.sh> Enabling Amazon Inspector"
    aws inspector2 enable --resource-types EC2 ECR LAMBDA --region "$REGION" --no-cli-pager >/dev/null 2>&1
    echo "<INFO::update-infra.sh> Enabling Security Hub"
    aws securityhub enable-security-hub >/dev/null 2>&1
    echo "<INFO::update-infra.sh> Enabling GuardDuty"
    aws aws guardduty create-detector --enable >/dev/null 2>&1

    # Enable Lambda pre-signed URLs on S3 output bucket.
    S3OutputBucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODOutputS3Bucket`].Value' --output text --no-cli-pager)
    S3LambdaArn=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODLambdaSignedURL`].Value' --output text --no-cli-pager)
    notif_conf="{\"LambdaFunctionConfigurations\":[{\"Id\": \"0\", \"LambdaFunctionArn\": \"$S3LambdaArn\", \"Events\": [\"s3:ObjectCreated:Put\"]}]}"

    if [[ -n $S3OutputBucket && -n $S3LambdaArn ]]; then
        echo "<INFO::update-infra.sh> Enabling Lambda signed URL notification on S3 output bucket"
        aws s3api put-bucket-notification-configuration --bucket "$S3OutputBucket" --notification-configuration "$notif_conf"
    else
        echo "<ERROR::update-infra.sh> Could not enable Lambda notifications for S3 output bucket file puts"
    fi

    # Build Secrets Manager secret
    ## This generates the fernet key used for the CSRF token
    csrfkey=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64)
    logouturl="https://${FQDN}/"
    sqsqueue=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODSQSUrl`].Value' --output text --no-cli-pager)
    toolstable=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODDynamoDBToolsTableName`].Value' --output text --no-cli-pager)
    inputbucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODWebUploadS3Bucket`].Value' --output text --no-cli-pager)
    outputbucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODOutputS3Bucket`].Value' --output text --no-cli-pager)
    lambdajwtarn=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODLambdaJWTARN`].Value' --output text --no-cli-pager)
    ProTODSecret="{\"csrfkey\":\"$csrfkey\", \"logouturl\":\"$logouturl\", \"sqsqueue\":\"$sqsqueue\", \"toolstable\":\"$toolstable\", \"inputbucket\":\"$inputbucket\", \"outputbucket\":\"$outputbucket\", \"lambdajwtarn\":\"$lambdajwtarn\"}"

    if [[ $CODEBUILD_DEPLOY == true ]]; then
        echo "<INFO::update-infra.sh> BUILD INFRA VARIABLES"
        echo "<INFO::update-infra.sh> CSRF: $csrfkey"
        echo "<INFO::update-infra.sh> Logout URL: $logouturl"
        echo "<INFO::update-infra.sh> SQS Queue: $sqsqueue"
        echo "<INFO::update-infra.sh> Tools table: $toolstable"
        echo "<INFO::update-infra.sh> Input bucket: $inputbucket"
        echo "<INFO::update-infra.sh> Output bucket: $outputbucket"
    fi

    # Set Secrets Manager secret
    SecretARN=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODSecret`].Value' --output text --no-cli-pager)
    if [[ -n $SecretARN ]]; then
        echo "<INFO::update-infra.sh> Writing Secret Manager secret"
        aws secretsmanager put-secret-value --secret-id "$SecretARN" --secret-string "$ProTODSecret"  >/dev/null 2>&1
    else
        echo "<ERROR::update-infra.sh> Could not write Secret Manager secret. Exiting. . ."
        return 80
    fi


    # Set Fargate front end service desired count to '1' and stop any running tasks
    echo "<INFO::update-infra.sh> Enabling frontend with ./scripts/frontend-control.sh --desired-1"
    . ./frontend-control.sh --desired-1
    if [[ $? == 80 ]]; then
        echo "<ERROR::build-infra.sh> Could not set Fargate front end service desired count to 1"
    fi
fi




if [[ $protod_disable == true ]]; then
    protod_disable=""
    echo "<INFO::update-infra.sh> Disabling ProTOD infrastructure."

    # Disable Lambda pre-signed URLs on S3 output bucket.
    S3OutputBucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODOutputS3Bucket`].Value' --output text --no-cli-pager)
    notif_conf="{\"LambdaFunctionConfigurations\":[]}"

    if [[ -n $S3OutputBucket ]]; then
        echo "<INFO::update-infra.sh> Disabling Lambda signed URL notification on S3 output bucket"
        aws s3api put-bucket-notification-configuration --bucket "$S3OutputBucket" --notification-configuration "$notif_conf"
    else
        echo "<ERROR::update-infra.sh> Could not disable Lambda notifications for S3 output bucket file puts"
    fi

    # Disable ELB logging
    #ELB=$(aws cloudformation list-exports --query 'Exports[?Name==`FrontEndALB`].Value' --output text --no-cli-pager | cut -d "/" -f3)

    #if [[ -n $ELB ]]; then
    #    echo "<INFO::build-infra.sh> Disabling ELB logging"
    #    aws elb modify-load-balancer-attributes --load-balancer-name "$ELB" --load-balancer-attributes AccessLog={Enabled=false}
    #else
    #    echo "<ERROR::build-infra.sh> Could not disable ELB logging"
   # fi

    # Set Fargate front end service desired count to '0' and stop any running tasks
    echo "<INFO::update-infra.sh> Disabling frontend with ./scripts/frontend-control.sh --desired-0"
    . ./frontend-control.sh --desired-0
    if [[ $? == 80 ]]; then
        echo "<ERROR::build-infra.sh> Could not set Fargate front end service desired count to 0"
        return 80
    fi
fi

echo "<INFO::update-infra.sh> update-infra.sh complete"
return 0
