#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

tool_version=$(clamscan -V)

echo "Running Freshclam from $tool_version"
echo "Command: freshclam --datadir=/tmp/ClamAVDB --log=/tmp/ClamAVLog"
freshclam --datadir=/tmp/ClamAVDB --log=/tmp/ClamAVLog ||
	{ echo " freshclam failed to run, exiting"; exit 1; }
echo "Copying ClamAV Virus Definition files to the input bucket"
aws s3 sync /tmp/ClamAVDB s3://"$JOB_INPUT_BUCKET"/ClamAV ||
	{ echo "Error copying files to the bucket, exiting"; exit 1; }
echo "Done"
