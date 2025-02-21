#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(detect-secrets --version)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: detect-secrets scan --all-files ./$TOOL_NAME"
    detect-secrets scan --all-files ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: detect-secrets scan --all-files ./$TOOL_NAME"
    detect-secrets scan --all-files ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    failure=$(grep -c "filename" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total failures: $failure"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh