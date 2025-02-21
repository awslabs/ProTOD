#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(cfn-lint --version | head -1 | cut -d " " -f 2)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: find ./$TOOL_NAME -type f \( -iname \*.yaml -o -iname \*.yml -o -iname \*.json \) -exec cfn-lint {} \;"
    find ./"$TOOL_NAME" -type f \( -iname \*.yaml -o -iname \*.yml -o -iname \*.json \) -exec cfn-lint {} \; | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: find ./$TOOL_NAME -type f \( -iname \*.yaml -o -iname \*.yml -o -iname \*.json \) -exec cfn-lint {} \;"
    find ./"$TOOL_NAME" -type f \( -iname \*.yaml -o -iname \*.yml -o -iname \*.json \) -exec cfn-lint {} \; &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    warning=$(grep -ce "^W[0-9]" ./"$myoutputfile")
    error=$(grep -ce "^E[0-9]" ./"$myoutputfile")
    info=$(grep -ce "^I[0-9]" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total warnings: $warning"
echo "Total errors: $error"
echo "Total infos: $info"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh
