#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

filetoolqueue="NoInternetQueue"
account=$(aws sts get-caller-identity --query Account) || exit 1
region=$(aws configure get default.region) || exit 1

while getopts "t:f:ld" flag
do
    case "${flag}" in
        t) tool=${OPTARG};;
        f) file=${OPTARG};;
        l) listall=1;;
        d) debug=1;;
        *) echo "Usage: $0 -f filename -t toolname -q batchQueue -d batchJobDefinition [-l] [-d]" >&2
            echo "-l optional. Lists all ProTOD tools for account $account and region $region"
            echo "-d optional. Wnables the DEBUG variable for the container, which provides additional output in CloudWatch"
            exit 1;;
    esac
done

if { [ "$listall" ]; }
    then
        protodtools=$(aws cloudformation list-exports --query 'Exports[?contains(Name, `ProTODECR`)].Value' --output text --no-cli-pager)
        echo "ProTOD tools for account $account and region $region are:"
        for ptool in $protodtools
            do
                mytool=$(echo "$ptool" | cut -d / -f 2)
                echo "    $mytool"
            done
    exit 1
fi

ProTODOutputS3Bucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODOutputS3Bucket`].Value' --output text --no-cli-pager)
ProTODInputS3Bucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODWebUploadS3Bucket`].Value' --output text --no-cli-pager)
ProTODSQSQueueURL=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODSQSUrl`].Value' --output text --no-cli-pager)
jobqueues=$(aws cloudformation list-exports --query 'Exports[?contains(Name, `Queue`)].Value' --output text --no-cli-pager)
jobdefinitions=$(aws cloudformation list-exports --query 'Exports[?contains(Name, `Definition`)].Value' --output text --no-cli-pager)

shopt -s nocasematch
for queue in $jobqueues
    do
        if [[ $queue =~ $filetoolqueue ]]
        then

            jobqueue=$(echo "$queue" | cut -d / -f 2)
            echo -e "Protod Batch queue for account $account in $region is: $jobqueue"
        fi
    done
if ! { [ "$jobqueue" ]; }
then
    echo "No Batch job queues found for $tool in account $account in $region"
    exit 1
fi

for definition in $jobdefinitions
    do
        if [[ $definition =~ $tool ]]
        then
            jobdefinition=$(echo "$definition" | cut -d / -f 2)
            echo -e "Protod Batch definition for account $account in $region is:\t$jobdefinition"
        fi
    done
if ! { [ "$jobdefinition" ]; }
then
    echo "No Batch job definition found for $tool in account $account in $region"
    exit 1
fi

if ! { [ "$tool" ] && [ "$file" ] && [ "$ProTODOutputS3Bucket" ] && [ "$ProTODInputS3Bucket" ] &&
        [ "$ProTODSQSQueueURL" ] && [ "$jobqueue" ] && [ "$jobdefinition" ]; }
        then
            echo "all parameters are required and you must be authenticated to a ProTOD account"
			echo "Usage: $0 -f filename -t toolname" >&2
        exit 1
fi

callerId=$(aws sts get-caller-identity) || exit 1
userId=$(echo "$callerId" | grep UserId | cut -d : -f 3 | sed -e 's/",//g' | cut -d - -f 1)
folder=$(uuidgen | sed -e 's/-//g')
date=$(date +%Y%m%d%H%M%S)
uploadfilename=$(echo "$file" | rev | cut -d / -f 1 | rev)
destination="$folder/$uploadfilename"
filename="$tool-$userId-$date"
jobname="$tool-$userId"

aws s3 cp "$file" "s3://$ProTODInputS3Bucket/$destination"

if { [ "$debug" ]; }; then
    aws batch submit-job \
        --job-name "$jobname" \
        --job-queue "$jobqueue" \
        --job-definition "$jobdefinition" \
        --container-overrides "environment=[{name=JOB_INPUT_BUCKET,value=$ProTODInputS3Bucket},\
            {name=JOB_OUTPUT_BUCKET,value=$ProTODOutputS3Bucket},\
            {name=TOOL_NAME,value=$tool},\
            {name=FOLDER,value=$folder},\
            {name=FILENAME,value=$filename.txt},\
            {name=SQS_QUEUE,value=$ProTODSQSQueueURL},
            {name=DEBUG,value=true}]" --no-cli-pager
else
    aws batch submit-job \
        --job-name "$jobname" \
        --job-queue "$jobqueue" \
        --job-definition "$jobdefinition" \
        --container-overrides "environment=[{name=JOB_INPUT_BUCKET,value=$ProTODInputS3Bucket},\
            {name=JOB_OUTPUT_BUCKET,value=$ProTODOutputS3Bucket},\
            {name=TOOL_NAME,value=$tool},\
            {name=FOLDER,value=$folder},\
            {name=FILENAME,value=$filename.txt},\
            {name=SQS_QUEUE,value=$ProTODSQSQueueURL}]" --no-cli-pager
fi