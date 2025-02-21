#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

tool_version=$(ls /opt/protod/script-all*)

export LAST_CONTAINER=true
source /opt/protod/script-all-start.sh
source /opt/protod/script-all-end.sh
