#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

myoutputfile="$TOOL_NAME-$timestamp.txt"
tool_version=$(clamscan -V | cut -d " " -f 2)

if [[ -v DEBUG ]]; then
	echo "Copying ClamAV Virus Definition files from the input bucket"
	mkdir /tmp/ClamAVDB ||
		{ echo "Error cmaking /tmp/ClamAVDB, exiting"; exit_script 1; }
	aws s3 sync s3://"$JOB_INPUT_BUCKET"/ClamAV/ /tmp/ClamAVDB/ ||
		{ echo "Error copying files from the input bucket, exiting"; exit_script 1; }
	echo "Done"
else
	mkdir /tmp/ClamAVDB &>/dev/null ||
		{ echo "Error cmaking /tmp/ClamAVDB, exiting"; exit_script 1; }
	aws s3 sync s3://"$JOB_INPUT_BUCKET"/ClamAV/ /tmp/ClamAVDB/ &>/dev/null ||
		{ echo "Error copying files from the input bucket, exiting"; exit_script 1; }
fi

if [[ -v DEBUG ]]; then
	echo "Running $TOOL_NAME $tool_version Scan"
	echo "Command: clamscan --database=/tmp/ClamAVDB ./$TOOL_NAME"
	clamscan --database=/tmp/ClamAVDB ./"$TOOL_NAME" | tee ./"$myoutputfile"
	echo "Done"
else
	echo "Running $TOOL_NAME $tool_version Scan"
	echo "Command: clamscan --database=/tmp/ClamAVDB ./$TOOL_NAME"
	clamscan --database=/tmp/ClamAVDB ./"$TOOL_NAME" &> ./"$myoutputfile"
fi

# -------- Gathering Stats --------
if [ -f ./"$myoutputfile" ]; then
	infected=$(grep "Infected files: " ./"$myoutputfile" | sed -e 's/Infected files: //g')
	total_lines=0 # ClamAV is not used to scan lines of code
else
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Total files scanned: $num_files"
echo "Total size of all files: $totalk_size"
echo "Total Infected files: $infected"
echo "------------------------------------"
echo "A detailed report will be emailed"

source /opt/protod/script-all-end.sh