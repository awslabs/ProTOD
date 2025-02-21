#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Optional arguments: --role"
    echo "          --role <IAMROLE> : Name of the IAM role to assume"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--role') buildrole=$2 ;;
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
        echo "<ERROR::delete-protod.sh> ./scripts/assume-role.sh did not succeed."
        return 80
    fi
fi

if [[ -z $BUILDBUCKET || -z $STACKNAME ]]; then
    echo "Export the BUILDBUCKET and STACKNAME variables"
    return 80
fi

# Determine if delete is being executed by CodeBuild
if [[ -n $CODEBUILD_BUILD_ARN ]]; then
    codebuild_deploy=true
else
    codebuild_deploy=false
fi

# Set AWS region
if [[ $codebuild_deploy == true ]]; then
    REGION=$AWS_DEFAULT_REGION
    export REGION
else
    REGION=$(aws configure get region)
    export REGION
fi

# Disable Amazon Inspector, Security Hub, and GuardDuty
echo "<INFO>::delete-protod.sh> Disabling Amazon Inspector"
aws inspector2 disable --resource-types EC2 ECR LAMBDA --region "$REGION" --no-cli-pager >/dev/null 2>&1
echo "<INFO>::delete-protod.sh> Disabling Security Hub"
aws securityhub disable-security-hub >/dev/null 2>&1
echo "<INFO::update-infra.sh> Disabling GuardDuty"
aws aws guardduty create-detector --no-enable >/dev/null 2>&1

# Delete all ProTOD ECR repositories
echo "<INFO::delete-protod.sh> Deleting all ProTOD ECR repositories"
ecr_repos=$(aws ecr describe-repositories --region "$REGION" --query 'repositories[?repositoryName.contains (@, `protod-`)].repositoryName' --output text --no-cli-pager)
for repo in $ecr_repos; do
    aws ecr delete-repository --repository-name "$repo" --force --no-cli-pager >/dev/null 2>&1
done

# Delete all ProTOD SNS topics
echo "<INFO::delete-protod.sh> Deleting SNS topics"
sns_topics=($(aws sns list-topics --region "$REGION" --query 'Topics[?TopicArn.contains(@, `protod-`)].TopicArn' --output text --no-cli-pager))
for topic in $sns_topics; do
    aws sns delete-topic --topic-arn "$topic" >/dev/null 2>&1
done


# Get S3 bucket locations
ProTODAccessLogBucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODAccessLogBucket`].Value' --output text --no-cli-pager)
ProTODOutputS3Bucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODOutputS3Bucket`].Value' --output text --no-cli-pager)
ProTODS3LogBucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODS3LogBucket`].Value' --output text --no-cli-pager)
ProTODWebUploadS3Bucket=$(aws cloudformation list-exports --query 'Exports[?Name==`ProTODWebUploadS3Bucket`].Value' --output text --no-cli-pager)

# Add deny s3:PutObject policy to S3 log buckets to prevent files from being written after emptying buckets.
echo "<INFO::delete-protod.sh> Adding deny s3:PutObject policy to S3 log buckets"
aws s3api put-bucket-policy --bucket "$ProTODAccessLogBucket" --policy "{\"Statement\":[{\"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:PutObject\", \"Resource\": \"arn:aws:s3:::$ProTODAccessLogBucket/*\"}]}"
aws s3api put-bucket-policy --bucket "$ProTODS3LogBucket" --policy "{\"Statement\":[{\"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:PutObject\", \"Resource\": \"arn:aws:s3:::$ProTODS3LogBucket/*\"}]}"

# Empty buckets, regardless of versioning configuration
echo "<INFO::delete-protod.sh> Deleting files in all S3 buckets"
python3 ./emptybuckets.py $ProTODAccessLogBucket $ProTODOutputS3Bucket $ProTODS3LogBucket $ProTODWebUploadS3Bucket

# Delete CloudWatch Log groups
echo "<INFO::delete-protod.sh> Removing CloudWatch Log groups"
log_groups=$(aws logs describe-log-groups --log-group-name-prefix "ProTOD" --query 'logGroups[*].logGroupName' --no-paginate | tr -d '[],"' )
for group in $log_groups; do
    aws logs delete-log-group --log-group-name $group
done

# Delete the CloudFormation stack
echo "<INFO::delete-protod.sh> Deleting CloudFormation stack. This can take up to 10 minutes, check CloudFormation for updates"
aws cloudformation delete-stack --stack-name "$STACKNAME"

return 0
