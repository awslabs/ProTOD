#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(terrascan version | cut -d " " -f 2)

if [[ -v DEBUG ]]; then
    echo "Copying init repo"
    cp -R /.terrascan .
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: terrascan scan --use-terraform-cache ./$TOOL_NAME"
    terrascan scan --use-terraform-cache ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: terrascan scan --use-terraform-cache ./$TOOL_NAME"
    cp -R /.terrascan . &> /dev/null
    terrascan scan --use-terraform-cache ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    low=$(grep -c "Severity.*:.*LOW" ./"$myoutputfile")
    medium=$(grep -c "Severity.*:.*MEDIUM" ./"$myoutputfile")
    high=$(grep -c "Severity.*:.*HIGH" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit 1
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total low: $low"
echo "Total medium: $medium"
echo "Total high: $high"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh