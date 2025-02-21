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
import json

import boto3
from modules.secretmgr import get_secret


class Config(object):
    session = boto3.session.Session()
    key = get_secret("app/protod", boto3.Session().region_name)
    ptod_key = json.loads(key)

    SECRET_KEY = ptod_key["csrfkey"]
    SESSION_TYPE = "redis"
    SESSION_PERMANENT = False
    SESSION_USE_SIGNER = True
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Strict"
    JWT_HEADER_NAME = "X-Amzn-Oidc-Data"
    LOGOUT_URL = ptod_key["logouturl"]
    SQS_QUEUE = ptod_key["sqsqueue"]
    MY_TOOL_TABLE = ptod_key["toolstable"]
    LAMBDA_JWT_ARN = ptod_key["lambdajwtarn"]
