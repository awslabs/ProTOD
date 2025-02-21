#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function print_help () {
    echo "Optional arguments: --desired-1, --desired-0, --disable"
    echo "          --desired-1 : Set Fargate frontend service desired count to 1"
    echo "          --desired-0 : Set Fargate frontend service desired count to 0 and stop any running tasks"
}


# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        '--desired-0') desired0=true ;;
        '--desired-1') desired1=true ;;
        '--help')
            print_help
            return 80 ;;
    esac
    shift
done

FrontEndCluster=$(aws cloudformation list-exports --query 'Exports[?Name==`FrontEndClusterName`].Value' --output text --no-cli-pager | cut -d "/" -f3)
FrontEndService=$(aws cloudformation list-exports --query 'Exports[?Name==`FrontEndServiceName`].Value' --output text --no-cli-pager | cut -d "/" -f3)

# Set Fargate front end service desired count to '0' and stop any running tasks
if [[ $desired0 == true ]]; then
    desired0=""
    if [[ -n $FrontEndCluster && -n $FrontEndService ]]; then
        echo "<INFO::frontend-control.sh> Setting Fargate front end service desired count to 0"
        aws ecs update-service --cluster $FrontEndCluster --service $FrontEndService --desired-count 0 >/dev/null 2>&1

        tasks=$(aws ecs list-tasks --cluster $FrontEndCluster --query 'taskArns' --output text | tr " " "\n")
        for task in $tasks; do
            echo "<INFO::frontend-control.sh> Stopping ECS task $task"
            aws ecs stop-task --cluster $FrontEndCluster --task $task --reason "Stopped by frontend-control.sh --desired-0" >/dev/null 2>&1
        done
    else
        echo "<ERROR::frontend-control.sh> Could not set Fargate front end service desired count to 0"
        return 80
    fi
    return 0
fi

 # Set Fargate front end service desired count to '0' and stop any running tasks
if [[ $desired1 == true ]]; then
    desired1=""
    if [[ -n $FrontEndCluster && -n $FrontEndService ]]; then
        echo "<INFO::frontend-control.sh> Setting Fargate front end service desired count to 1"
        aws ecs update-service --cluster $FrontEndCluster --service $FrontEndService --desired-count 1 >/dev/null 2>&1
    else
        echo "<ERROR::frontend-control.sh> Could not set Fargate front end service desired count to 1"
        return 80
    fi
    return 0
fi
