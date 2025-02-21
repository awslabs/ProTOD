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
import uuid

import boto3
from botocore.exceptions import NoCredentialsError
from flask import url_for
from modules.tools import Tools


def populate_tools(server_redis, tool_table):
    if not server_redis.exists("TOOLS_ALLOWED"):
        ta = Tools.build_keys(tool_table)
        server_redis.set("TOOLS_ALLOWED", ta)
    else:
        pass
    if not server_redis.exists("TOOL_DETAIL"):
        td = Tools("None", server_redis.get("TOOLS_ALLOWED"), tool_table).all_tools()
        server_redis.set("TOOL_DETAIL", td)
        multiscan_tools = _get_multiscan_tools(td)
        server_redis.set("MULTISCAN_TOOLS", multiscan_tools)
    else:
        pass


def get_my_region(server_redis):
    server_redis.set("MY_REGION", boto3.session.Session().region_name)


def _get_multiscan_tools(tools):
    tool_dict = {}
    for tool in tools:
        if tool["MULTISCAN"]["S"].lower() in "true":
            tool_string = tool["TOOL_META"]["M"]["LANGUAGES"]["S"]
            tool_list = tool_string.split(",")
            for tool_lang in tool_list:
                if tool_lang:
                    tool_dict.setdefault(tool_lang.strip(), []).append(
                        tool["TOOL_NAME"]["S"]
                    )
    for item in tool_dict:
        new_list = sorted(tool_dict[item], key=lambda tool_dict: tool_dict[0])
        tool_dict[item] = new_list
    return dict(sorted(tool_dict.items()))


def session_setup(session, server_redis, config):
    session["BATCH_SCANS"] = ""
    session["SUB_STAT"] = ""
    session["SESSION_ID"] = uuid.uuid4().hex
    session["LAST_URL"] = url_for("index")
    server_redis.set("JWT_HEADER_NAME", config["JWT_HEADER_NAME"])
    server_redis.set("LAMBDA_JWT_ARN", config["LAMBDA_JWT_ARN"])
    server_redis.set("SQS_QUEUE", config["SQS_QUEUE"])
    server_redis.set("MY_TOOL_TABLE", config["MY_TOOL_TABLE"])
    get_my_region(server_redis)


def aws_session(my_region):
    fn_session = boto3.Session(
        region_name=my_region,
    )
    return fn_session


def isauth(session, server_redis, config) -> bool:
    try:
        session["SUB_STAT"]
    except KeyError:
        session_setup(session, server_redis, config)
    fn_session = aws_session(server_redis.get("MY_REGION"))
    auth = fn_session.get_credentials()
    if auth is None:
        return False
    else:
        return True


def getRegions(server_redis) -> list:
    try:
        fn_session = aws_session(server_redis.get("MY_REGION"))
        ec2 = fn_session.client("ec2")
        ec2_responses = ec2.describe_regions(AllRegions=True)
        my_regions = []
        for resp in ec2_responses["Regions"]:
            my_regions.append(resp["RegionName"])
        my_regions.sort()
        return my_regions
    except NoCredentialsError as err:
        return err
