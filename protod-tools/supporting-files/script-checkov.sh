#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(checkov --version)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: checkov --skip-download -d ./$TOOL_NAME"
    checkov --skip-download -d ./"$TOOL_NAME" | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: checkov --skip-download -d ./$TOOL_NAME"
    checkov --skip-download -d ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    failure=$(grep -c "FAILED" ./"$myoutputfile")
    pass=$(grep -c "PASSED" ./"$myoutputfile")
    skipped=$(grep -c "SKIPPED" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total failures: $failure"
echo "Total passed: $pass"
echo "Total skipped: $skipped"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh