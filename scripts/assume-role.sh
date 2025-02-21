#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Required arguments: --role"
    echo "          --role <IAMROLE> : Name of the IAM role to assume"
}


# If the script is run with no arguments, print the help
if [[ $# -eq 0 ]]; then
    print_help
    echo "<ERROR::assume-role.sh> Script run with no arguments."
    return 88
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--role') buildrole=$2 ;;
        '--help')
            print_help
            return 88 ;;
    esac
    shift
done

# If global var ACCOUNT not defined, return error
if [[ -z $ACCOUNT ]]; then
    echo "<ERROR::assume-role.sh> Global variable 'ACCOUNT' not defined."
    return 88
fi

# Build the IAM role ARN and STS caller identity ARN
buildrolearn="arn:aws:iam::$ACCOUNT:role/$buildrole"
stscalleridentityarn="arn:aws:sts::$ACCOUNT:assumed-role/$buildrole/build-session"

# Check if AWS CLI has already assumed the role
if [[ $(aws sts get-caller-identity --query 'Arn' | tr -d '"') == "$stscalleridentityarn" ]]; then
    echo "<INFO::assume-role.sh> Already assumed IAM role $buildrolearn"
    return 0
fi

# Assume IAM role for build
export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" \
$(aws sts assume-role \
--role-arn $buildrolearn \
--role-session-name build-session \
--query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
--output text))

# Check that AWS CLI is connected to the correct account
if [[ $(aws sts get-caller-identity --query 'Account' | tr -d '"') == $ACCOUNT ]]; then
    echo "<INFO::assume-role.sh> Successfully assumed IAM role $buildrolearn"
else
    echo "<ERROR::assume-role.sh> Error assuming role $buildrolearn"
    return 88
fi
