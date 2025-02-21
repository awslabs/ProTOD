#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(shellcheck --version | head -n 2 | tail -n 1 | cut -d " " -f 2)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: shellcheck ./$TOOL_NAME/*"
    shellcheck ./"$TOOL_NAME"/* | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: shellcheck ./$TOOL_NAME/*"
    shellcheck ./"$TOOL_NAME"/* &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    error=$(grep -c "(error):" ./"$myoutputfile")
    warning=$(grep -c "(warning):" ./"$myoutputfile")
    info=$(grep -c "(info):" ./"$myoutputfile")
    style=$(grep -c "(style):" ./"$myoutputfile")
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "Total failures: $error"
echo "Total warnings: $warning"
echo "Total info: $info"
echo "Total style: $style"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh