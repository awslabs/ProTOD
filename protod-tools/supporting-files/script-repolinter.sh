#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(node /usr/local/repolinter/bin/repolinter.js --version)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: node /usr/local/repolinter/bin/repolinter.js lint ./$TOOL_NAME -r /opt/protod/repolinter-amazon-ospo-ruleset.json -f markdown"
    node /usr/local/repolinter/bin/repolinter.js lint ./"$TOOL_NAME" -r /opt/protod/repolinter-amazon-ospo-ruleset.json -f markdown 2>&1 | tee ./"$myoutputfile"
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: node /usr/local/repolinter/bin/repolinter.js lint ./$TOOL_NAME -r /opt/protod/repolinter-amazon-ospo-ruleset.json -f markdown"
    node /usr/local/repolinter/bin/repolinter.js lint ./"$TOOL_NAME" -r /opt/protod/repolinter-amazon-ospo-ruleset.json -f markdown &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    error=$(head -n 8 ./"$myoutputfile" | tail -1 | cut -d "|" -f 2 | sed -e 's/ //g')
    failure=$(head -n 8 ./"$myoutputfile" | tail -1 | cut -d "|" -f 3 | sed -e 's/ //g')
    warning=$(head -n 8 ./"$myoutputfile" | tail -1 | cut -d "|" -f 4 | sed -e 's/ //g')
    pass=$(head -n 8 ./"$myoutputfile" | tail -1 | cut -d "|" -f 5 | sed -e 's/ //g')
    skipped=$(head -n 8 ./"$myoutputfile" | tail -1 | cut -d "|" -f 6 | sed -e 's/ //g')
    echo "---------- Summary Report ----------"
    echo "Total files scanned: $num_files"
    echo "Total size of all files: $totalk_size"
    echo "Total lines of code: $total_lines"
    echo "Total error: $error"
    echo "Total failure: $failure"
    echo "Total warning: $warning"
    echo "Total pass: $pass"
    echo "Total skipped: $skipped"
    echo "------------------------------------"
    echo "A detailed report will be emailed"
else
    echo "No output file, exiting."
    exit_script
fi

source /opt/protod/script-all-end.sh