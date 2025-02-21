#!/bin/sh
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
gunicorn --chdir /usr/src app:app -w 4 --threads 4 \
--worker-class=gthread --log-file=- --worker-tmp-dir /dev/shm  -b 0.0.0.0:8080
