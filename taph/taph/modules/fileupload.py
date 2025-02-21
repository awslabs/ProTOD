"""  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
  
  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
      http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
"""
import boto3
import logging
import os

# Setup Default Logger
log_level: str = os.environ.get("LOG_LEVEL", "DEBUG")
LOGGER = logging.getLogger().setLevel(log_level)


class FileUpload:
    def __init__(self, src, bucket, dst):
        self.src = src
        self.bucket = bucket
        self.dst = dst

    def s3_client(self):
        try:
            self.session = boto3.session.Session()
            self.client = self.session.client("s3")
        except Exception as e:
            logging.error(f"A client exception occurred :: {e}")
        else:
            return self.client
        return None

    def file_upload_s3(self):
        try:
            self.client = self.s3_client()
            self.response = self.client.put_object(
                Body=self.src,
                Bucket=self.bucket,
                Key=self.dst,
                ServerSideEncryption="AES256",
            )
            logging.info("Upload Succeeded")
            return self.response
        except Exception as e:
            logging.error(e)
