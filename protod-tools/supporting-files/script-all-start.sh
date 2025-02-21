#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

if [[ -v DEBUG ]]; then echo "Starting Container"; fi

mydate=$(date +%s)
timestamp=$((mydate * 100000 + RANDOM))

function update_schema() {
    JSON="{
    'id': {'N': ''},
    'AWS_BATCH_JOB_ID': {'S': '$AWS_BATCH_JOB_ID'},
    'DSR_TICKET': {'S': '$dsr_ticket'},
    'NUM_FILES': {'N': '$num_files'},
    'TOTALK_SIZE': {'N': '$totalk_size'},
    'TOTAL_LINES': {'N': '$total_lines'},
    'OPERATOR': {'S': '$operator'},
    'USERNAME': {'S': '$username'},
    'CREATED_AT': {'N': '0'},
    'STARTED_AT': {'N': '0'},
    'STOPPED_AT': {'N': '0'},
    'JOB_STATUS': {'S': ''},
    'TOOL_NAME': {'S': '$TOOL_NAME'},
    'TOOL_VERSION': {'S': '$tool_version'},
    'INTERNAL_BUCKET': {'N': '$internal_bucket'},
    'EXTERNAL_BUCKET': {'N': '$external_bucket'},
    'FINDING_SEVERITY': {'M': {
    'CRITICAL': {'N': '$critical'},
    'HIGH': {'N': '$high'},
    'MEDIUM': {'N': '$medium'},
    'LOW': {'N': '$low'},
    'UNDEFINED': {'N': '$undefined'},
    'FAILURE': {'N': '$failure'},
    'ERROR': {'N': '$error'},
    'WARNING': {'N': '$warning'},
    'INFO': {'N': '$info'},
    'STYLE': {'N': '$style'},
    'PASS': {'N': '$pass'},
    'INFECTED': {'N': '$infected'},
    'SKIPPED': {'N': '$skipped'},
    'NOTICE': {'N': '$notice'}
    }}
    }"
}

function set_bucket_variables() {
    if [[ -v EXTERNAL_BUCKET ]] && [[ BOTH_BUCKETS -eq 1 ]]; then
        if [[ -v DEBUG ]]; then echo "Using the external bucket only"; fi
        internal_bucket=1
        external_bucket=0
    elif [[ -v EXTERNAL_BUCKET ]] && [[ BOTH_BUCKETS -eq 0 ]]; then
        if [[ -v DEBUG ]]; then echo "Using both internal and extenral buckets"; fi
        internal_bucket=0
        external_bucket=0
    else
        if [[ -v DEBUG ]]; then echo "Using the internal bucket only"; fi
        internal_bucket=0
        external_bucket=1
    fi
}

function set_variables() {
    id=0
    dsr_ticket=""
    num_files=0
    totalk_size=0
    total_lines=0
    tool_version=""
    operator="$USER_SUB"
    username="$USERNAME"
    run_time=0
    low=0
    medium=0
    high=0
    critical=0
    undefined=0
    failure=0
    error=0
    warning=0
    info=0
    style=0
    pass=0
    infected=0
    skipped=0
    notice=0
    set_bucket_variables
}

function exit_script() {
    set_variables
    update_schema
    if { [[ "$SQS_QUEUE" =~ ^[\-a-zA-Z0-9\./:]+$ ]] && [[ -v DEBUG ]]; } then
        echo "Exit script activated."
        echo "Sending results to SQS to be added to the DynamoDB scan table"
        aws sqs send-message --queue-url "$SQS_QUEUE" --message-body "$JSON" --no-cli-pager ||
            { echo "Error sending data to SQS, exiting"; exit 0; }
        echo "Exiting."
        exit 0
    elif [[ "$SQS_QUEUE" =~ ^[\-a-zA-Z0-9\./:]+$ ]]; then
        aws sqs send-message --queue-url "$SQS_QUEUE" --message-body "$JSON" --no-cli-pager &>/dev/null ||
            { echo "Error sending data to SQS, exiting"; exit 0; }
        echo "Exiting."
        exit 0
    else
        echo "Exiting."
        exit 0
    fi
}

function remove_files_from_input_bucket() {
    if [[ -v DEBUG ]]; then
        echo "Input ENV variables invalid or last container, trying to remove files from the input bucket."
        aws s3 rm s3://"$JOB_INPUT_BUCKET"/"$FOLDER" --recursive ||
            { echo "Error removing files from the input bucket, exiting"; exit_script; }
    fi
    aws s3 rm s3://"$JOB_INPUT_BUCKET"/"$FOLDER" --recursive &>/dev/null ||
        { echo "Error removing files from the input bucket, exiting"; exit_script; }
}

function validate_file_containers_variables() {
    if { [[ "$JOB_INPUT_BUCKET" =~ ^[\-a-z0-9\.]+$ ]] &&
        [[ "$JOB_OUTPUT_BUCKET" =~ ^[\-a-z0-9\.]+$ ]] &&
        [[ "$TOOL_NAME" =~ ^[a-zA-Z0-9]+$ ]] &&
        [[ "$FOLDER" =~ ^[a-z0-9]+$ ]] &&
        [[ "$USER_SUB" =~ ^[a-z0-9]+$ ]] &&
        [[ "$SQS_QUEUE" =~ ^[\-a-zA-Z0-9\./:]+$ ]] &&
        [[ "$USERNAME" =~ ^[\-a-zA-Z0-9\._]+$ ]]; }
        then
            if [[ -v DEBUG ]]; then
                echo "Input ENV variables valid"
            fi
            return 0;
        else
            remove_files_from_input_bucket
            echo "Exiting"
            exit_script
    fi
}

function validate_external_bucket_variables() {
    if { [[ "$EXTERNAL_BUCKET" =~ ^[\-a-z0-9\.]+$ ]] &&
        [[ "$EXTERNAL_ID" =~ ^[\-a-zA-Z0-9]+$ ]] &&
        [[ "$ROLE_ARN" =~ ^[\-a-zA-Z0-9\./:]+$ ]] &&
        [[ "$BOTH_BUCKETS" =~ ^[0-1]$ ]]; }
        then
            if [[ -v DEBUG ]]; then
                echo "External Bucket variables are valid"
            fi
            return 0;
        else
            echo "External Bucket variables are invalid"
            remove_files_from_input_bucket
            echo "Exiting"
            exit_script
    fi
}

function validate_no_files_containers_variables() {
    if { [[ "$JOB_OUTPUT_BUCKET" =~ ^[\-a-z0-9\.]+$ ]] &&
        [[ "$TOOL_NAME" =~ ^[a-zA-Z0-9]+$ ]] &&
        [[ "$USER_SUB" =~ ^[a-z0-9]+$ ]] &&
        [[ "$SQS_QUEUE" =~ ^[\-a-zA-Z0-9\./:]+$ ]] &&
        [[ "$USERNAME" =~ ^[\-a-zA-Z0-9\._]+$ ]]; }
        then
            if [[ -v DEBUG ]]; then
                echo "Input ENV variables valid"
            fi
            return 0;
        else
            echo "Exiting"
            exit_script
    fi;
}

function validate_container_parameters() {
    if [[ $var =~ ^[\-a-zA-Z0-9\./:_\ ]+$ ]]
        then
            if [[ -v DEBUG ]]; then
                echo "Input parameters valid"
            fi
            return 0;
        else
            if [[ -v DEBUG ]]; then
                echo "Input Parameters invalid."
            fi
            echo "Exiting"
            exit_script
    fi;
}

function copy_files_from_input_bucket() {
    if [[ -v DEBUG ]]; then
        echo "Copying files from the input bucket"
        aws s3 sync s3://"$JOB_INPUT_BUCKET"/"$FOLDER" ./"$TOOL_NAME" ||
            { echo "Error copying files from the input bucket, exiting"; exit_script; }
 #       echo "Removing file from the input bucket"
 #       aws s3 rm s3://"$JOB_INPUT_BUCKET"/"$FOLDER" --recursive ||
 #           { echo "Error removing files from the input bucket, exiting"; exit_script; }
    else
        aws s3 sync s3://"$JOB_INPUT_BUCKET"/"$FOLDER" ./"$TOOL_NAME" &>/dev/null ||
            { echo "Error copying files from the input bucket, exiting"; exit_script; }
#        aws s3 rm s3://"$JOB_INPUT_BUCKET"/"$FOLDER" --recursive &>/dev/null ||
#            { echo "Error removing files from the input bucket, exiting"; exit_script; }
    fi
}

function unzip_files() {
    if [[ -v DEBUG ]]; then
        echo "Checking for zip files"
        shopt -s nullglob
        zipfiles=$(find ./"$TOOL_NAME" -type f -name \*.zip)
        if [[ $zipfiles ]]; then
            for zipfile in $zipfiles; do
                echo "Unzipping $zipfile"
                unzip -o -d "$(dirname "$zipfile")" "$zipfile"
                echo "Removing $zipfile"
                rm -f "$zipfile"
            done
        else
            echo "No zip files found"
        fi
        shopt -u nullglob
    else
        shopt -s nullglob
        zipfiles=$(find ./"$TOOL_NAME" -type f -name \*.zip)
        if [[ $zipfiles ]]; then
            for zipfile in $zipfiles; do
                unzip -o -d "$(dirname "$zipfile")" "$zipfile" &>/dev/null
                rm -f "$zipfile" &>/dev/null
            done
        fi
        shopt -u nullglob
    fi
}

function check_for_files() {
    if [[ -v DEBUG ]]; then
        echo "Checking for files"
    fi
    shopt -s nullglob
    files=$(find ./"$TOOL_NAME" -type f)
    if [[ -z $files ]]; then
        echo "No files found, exiting."
        exit_script
    else
        num_files=$(find ./"$TOOL_NAME" -type f | wc -l | sed 's/ //g')
        total_lines=$(find ./"$TOOL_NAME" -type f -exec grep -I . {} \; | wc -l)
        totalk_size=$(du -ks ./"$TOOL_NAME" | cut -f 1)
        shopt -u nullglob
    fi
}

function show_debug_vars() {
    echo "--------- DEBUG Variables ---------"
    echo "Username: $USERNAME"
    echo "Operator: $USER_SUB"
    echo "Input bucket: $JOB_INPUT_BUCKET"
    echo "Ouput bucket: $JOB_OUTPUT_BUCKET"
    echo "External bucket: $EXTERNAL_BUCKET"
    echo "External ID: $EXTERNAL_ID"
    echo "Role ARN: $ROLE_ARN"
    echo "Both buckets: $BOTH_BUCKETS"
    echo "Folder: $FOLDER"
    echo "Tool name: $TOOL_NAME"
    echo "User sub: $USER_SUB"
    echo "SQS queue: $SQS_QUEUE"
    echo "AWS Batch Job ID: $AWS_BATCH_JOB_ID"
    echo "Last container: $LAST_CONTAINER"
    echo "-----------------------------------"
}

if [[ -v DEBUG ]]; then show_debug_vars; fi

if [[ -v EXTERNAL_BUCKET ]]; then validate_external_bucket_variables; fi

if { [[ $TOOL_NAME == "prowler" ]] && [[ ! -v LAST_CONTAINER ]]; }; then
    set_variables
    validate_no_files_containers_variables
    # Supressing Semgrep as the IFS separator is only manipulated in a subshell and is done for Bash compatibility on a Mac.
    # nosemgrep: ifs-tampering
    var=$( IFS=$' '; echo "${@}" )
    validate_container_parameters
elif [[ ! -v LAST_CONTAINER ]]; then
    set_variables
    validate_file_containers_variables
    copy_files_from_input_bucket
    unzip_files
    check_for_files
else
    set_variables
    if { [[ $TOOL_NAME != "prowler" ]]; } then
        remove_files_from_input_bucket
    fi
fi