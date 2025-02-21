#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.zip"
tool_version=$(prowler --version | cut -d " " -f 2 2>/dev/null)

if [[ -v DEBUG ]]; then
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: prowler aws $var"
    prowler aws $var || # Do not doublequote $var! Words need splitting or it will not work.
        { echo "Error running prowler, exiting"; exit_script; }
    zip -r ./"$myoutputfile" ./output/ ||
        { echo "Error zipping files because there is no output, exiting"; exit_script; }
    echo "Done"
else
    echo "Running $TOOL_NAME $tool_version Scan"
    echo "Command: prowler aws $var"
    prowler aws $var &> /dev/null || # Do not doublequote $var! Words need splitting or it will not work.
        { echo "Error running prowler, exiting"; exit_script; }
    zip -qr ./"$myoutputfile" ./output/ &>/dev/null ||
        { echo "Error no ouput, exiting"; exit_script; }
fi


# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
    myfile=$(find . -name prowler\*.csv | grep -v _ )
    pass=$(grep -c ";PASS;" < "$myfile")
    failure=$(grep -c ";FAIL;" < "$myfile")
    info=$(grep -c ";INFO;" < "$myfile")
    low=$(grep -c ";FAIL;.*;low;" < "$myfile")
    medium=$(grep -c ";FAIL;.*;medium;" < "$myfile")
    high=$(grep -c ";FAIL;.*;high;" < "$myfile")
    critical=$(grep -c ";FAIL;.*;critical;" < "$myfile")
    total_lines=0 # Prowler is not used to scan lines of code
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total passed: $pass"
echo "Total failed: $failure"
echo "Total info: $info"
echo "Total failed with severity low: $low"
echo "Total failed with severity medium: $medium"
echo "Total failed with severity high: $high"
echo "Total failed with severity critical: $critical"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh
