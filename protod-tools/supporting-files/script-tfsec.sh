#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(tfsec --version)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: tfsec --no-color ./$TOOL_NAME"
    tfsec --no-color ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: tfsec --no-color ./$TOOL_NAME"
    tfsec --no-color ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    low=$(tail -10 ./"$myoutputfile" | grep "low" | awk '{print $2}')
    medium=$(tail -10 ./"$myoutputfile" | grep "medium" | awk '{print $2}')
    high=$(tail -10 ./"$myoutputfile" | grep "high" | awk '{print $2}')
    critical=$(tail -10 ./"$myoutputfile" | grep "critical" | awk '{print $2}')
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
echo "Total high: $critical"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh