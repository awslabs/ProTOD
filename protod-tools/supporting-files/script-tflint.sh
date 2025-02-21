#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(tflint -v | head -n 1 | cut -d " " -f 3)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: tflint --chdir ./$TOOL_NAME"
    tflint --chdir ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: tflint --chdir ./$TOOL_NAME"
    tflint --chdir ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    error=$(grep -c "Error" ./"$myoutputfile")
    warning=$(grep -c "Warning" ./"$myoutputfile")
    notice=$(grep -c "Notice" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total low: $error"
echo "Total medium: $warning"
echo "Total high: $notice"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh