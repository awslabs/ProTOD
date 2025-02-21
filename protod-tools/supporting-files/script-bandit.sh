#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(bandit --version | head -1 | cut -d " " -f 2)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: bandit -r ./$TOOL_NAME"
    bandit -r ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: bandit -r ./$TOOL_NAME"
    bandit -r ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    undefined=$(grep "Undefined:" ./"$myoutputfile" | head -1 | sed 's/.*Undefined: //g')
    low=$(grep "Low:" ./"$myoutputfile" | head -1 | sed 's/.*Low: //g')
    medium=$(grep "Medium:" ./"$myoutputfile" | head -1 | sed 's/.*Medium: //g')
    high=$(grep "High:" ./"$myoutputfile" | head -1 | sed 's/.*High: //g')
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total undefined: $undefined"
echo "Total low: $low"
echo "Total medium: $medium"
echo "Total high: $high"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh
