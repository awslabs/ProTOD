#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.zip"
tool_version=$(kics version | cut -d " " -f 6)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: kics scan -p ./$TOOL_NAME -o ./ -m --report-formats all"
    kics scan -p ./"$TOOL_NAME" -o ./ -m --report-formats all
    zip ./"$myoutputfile" ./*results*
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: kics scan -p ./$TOOL_NAME -o ./ -m --report-formats all"
    kics scan -p ./"$TOOL_NAME" -o ./ -m --report-formats all &> /dev/null
    zip -q ./"$myoutputfile" ./*results*
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    info=$(grep -c INFO ./results.csv)
    low=$(grep -c LOW ./results.csv)
    medium=$(grep -c MEDIUM ./results.csv)
    high=$(grep -c HIGH ./results.csv)
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total info: $info"
echo "Total low: $low"
echo "Total medium: $medium"
echo "Total high: $high"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh