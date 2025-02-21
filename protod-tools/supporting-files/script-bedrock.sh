#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

source /opt/protod/script-all-start.sh

tool_version=$(python /opt/protod/generativeai.py -v| cut -d " " -f 2)

files=$(find ./"$TOOL_NAME" -type f \( -iname \*.sh -o -iname \*.py -o -iname \*.yaml -o -iname \*.yml -o -iname \*.json -o -iname \*.ts -o -iname \*.js -o -iname \*.tf \))
numfiles=( $files )

if [[ ${#numfiles[@]} -eq 0 ]]; then
    echo "Received $num_files but no files found for processing, exiting."
    exit_script
fi

if [[ $AI_PROMPT -eq "1" ]]; then
    qtype="threat model"
    question="Generate a detailed threat model"
elif [[ $AI_PROMPT -eq "2" ]]; then
    qtype="vulnerabilities and remediations"
    question="Find vulnerabilities and provide remediation recommendations"
elif [[ $AI_PROMPT -eq "3" ]]; then
    qtype="code comments"
    question="Add comments to the code"
else
    echo "Invalid prompt received"
    exit_script
fi

if [[ $TOOL_NAME == "bedrock" ]]; then
    myoutputfile="$TOOL_NAME-$qtype-$timestamp.md"
else
    myoutputfile="$TOOL_NAME-bedrock-$qtype-$timestamp.md"
    TOOL_NAME="bedrock-$TOOL_NAME"
fi

for file in $files
do
    if [[ -v DEBUG ]]; then
            echo "Running Bedrock $tool_version"
            echo "Running $qtype on $file"
            echo -e "\n========== $qtype for $file ==========\n" | tee -a ./"$myoutputfile.tmp"
            python ./generativeai.py -x 4000 -q "$question" "$file" | tee -a ./"$myoutputfile.tmp"
            echo "Done"
    else
        echo "Running Bedrock $tool_version"
        echo -e "\n========== $qtype for $file ==========n" &>> ./"$myoutputfile.tmp"
        python ./generativeai.py -x 4000 -q "$question" "$file" &>> ./"$myoutputfile.tmp"
    fi
done

if [[ ${#numfiles[@]} -gt 1 ]]; then
    if [[ $AI_PROMPT -eq "1" ]]; then
        python ./generativeai.py -x 4000 -q "Summarize the threat models into one threat model and provide specific mitigation recommendations" ./"$myoutputfile.tmp" &>> ./"$myoutputfile"
        cat ./"$myoutputfile.tmp" >> ./"$myoutputfile"
    fi
    if [[ $AI_PROMPT -eq "2" ]]; then
        python ./generativeai.py -x 4000 -q "Summarize the vulnerabilities and remediations" ./"$myoutputfile.tmp" &>> ./"$myoutputfile"
        cat ./"$myoutputfile.tmp" >> ./"$myoutputfile"
    fi
    if [[ $AI_PROMPT -eq "3" ]]; then
        mv ./"$myoutputfile.tmp" ./"$myoutputfile"
    fi
else
    mv ./"$myoutputfile.tmp" ./"$myoutputfile"
fi

shopt -u nullglob

if [ ! -f ./"$myoutputfile" ]; then
    echo "No output file, exiting."
    exit_script
fi

echo "---------- Summary Report ----------"
echo "Bedrock generated: $qtype"
echo "Total files reveived: $num_files"
echo "Total number of files processed by Bedrock: ${#numfiles[@]}"
echo "Total size of all files: $totalk_size"
echo "Total lines of code: $total_lines"
echo "------------------------------------"
echo "A detailed report will be emailed"

num_files=${#numfiles[@]}

source /opt/protod/script-all-end.sh