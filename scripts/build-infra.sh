#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Set script home directory
scriptdir=$(pwd)

if ! { [ "$BUILDBUCKET" ] && [ "$COGNITODOMAIN" ] &&\
     [ "$PROTODCERTIFICATE" ] && [ "$FQDN" ] &&\
     [ "$STACKNAME" ] && [ "$ALBLOGACCOUNT" ] && [ "$EMAIL" ]; }; then
        echo "<ERROR::build-infra.sh> Not all ProTOD variables are defined. Exiting. . ."
        return 80
fi

# Deploy CloudFormation stack
cd ../cloudformation
aws cloudformation package --template-file RootStack.yaml --s3-bucket "$BUILDBUCKET" --output-template package.yaml
aws cloudformation deploy --template-file package.yaml --stack-name "$STACKNAME" --capabilities CAPABILITY_NAMED_IAM --parameter-overrides "pProTODCognitoDomain=$COGNITODOMAIN" "pProTODCertificate=$PROTODCERTIFICATE" "pProTODDNS=$FQDN" "pALBLogAccount=$ALBLOGACCOUNT" "pAdminEmailAddress=$EMAIL"
cd $scriptdir

# Confirm the CloudFormation stack deployed properly.
stack_status=$(aws cloudformation describe-stacks --stack-name $STACKNAME --query 'Stacks[].StackStatus[]' --output text)
if [[ $stack_status == "CREATE_COMPLETE" || $stack_status == "UPDATE_COMPLETE" ]]; then
    echo "<INFO::build-infra.sh> build-infra.sh complete"
else
    echo "<ERROR::build-infra.sh> Failed to create CloudFormation stack $STACKNAME with template RootStack.yaml. Creation failed, exiting. . ."
    return 80
fi

