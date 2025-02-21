#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Check if brew is installed.
brew=$(which brew)
if [[ $brew == "brew not found" ]]
then
    echo "Homebrew (brew) not found. Installing. . ."
    # This script is optional if you want to test and deploy from a Mac. If used, this mirrors the installation instructions of Homebrew.
    # nosemgrep: curl-pipe-bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check if Finch is installed
finch=$(which finch)
if [[ $finch == "finch not found" ]]
then
    echo "Finch not found. Installing. . ."
    brew install --cask finch
    echo "Initializing Finch. . ."
    finch vm init
fi

# Check if Finch is running
finch_status=$(finch vm status)
if [[ ! $finch_status == "Running" ]]
then
    finch vm init
    finch vm start
fi

# Check if AWS CLI is connected
aws_account=$(aws sts get-caller-identity --query 'Account')
if [[ ! $aws_account ]]
then
    echo "AWS CLI is not authenticated. Please authenticate to the AWS CLI and set your default region."
    exit 1
fi

# Setup Python virtual environment and install requirements
cd ..
python3 -m venv venv
source ./venv/bin/activate
python3 -m pip install --no-cache-dir --upgrade pip
pip3 install -r taph/requirements.txt
pip3 install virtualenv pytest pytest-cov bandit safety
