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
from modules.dboperations import load_keys, open_session
from modules.simplyred import RedisClient


class Tools:
    def __init__(self, tool_name, tools_allowed, table_name, server_redis=None):
        self.tool_name = tool_name
        self.dynamo_client, self.my_region = open_session()
        self.tools_allowed = tools_allowed
        self.table_name = table_name
        for tool in list(tools_allowed):
            if tool["TOOL_NAME"]["S"] == tool_name:
                if server_redis.exists("TOOL_DETAIL"):
                    cache_lookup = server_redis.get("TOOL_DETAIL")
                    match = next(
                        (
                            label
                            for label in cache_lookup
                            if label["TOOL_NAME"]["S"] == tool_name
                        ),
                        None,
                    )
                    response = {} | {"Item": match}  # Python 3.9 merge operator
                else:
                    my_key = {
                        "TOOL_NAME": tool["TOOL_NAME"],
                        "TOOL_TYPE": tool["TOOL_TYPE"],
                    }
                    response = self.dynamo_client.get_item(
                        TableName=table_name, Key=my_key
                    )
                self.job_queue = response["Item"]["JOB"]["M"]["JOB_QUEUE"]["S"]
                self.job_definition = response["Item"]["JOB"]["M"]["JOB_DEFINITION"][
                    "S"
                ]
                self.job_role = response["Item"]["JOB"]["M"]["JOB_ROLE"]["S"]
                self.job_input_bucket = response["Item"]["JOB"]["M"][
                    "JOB_INPUT_BUCKET"
                ]["S"]
                self.job_output_bucket = response["Item"]["JOB"]["M"][
                    "JOB_OUTPUT_BUCKET"
                ]["S"]
                self.tool_meta = response["Item"]["TOOL_META"]["M"]

    def scan_tools(self):
        allowed = []
        for tool in self.tools_allowed:
            if tool["TOOL_TYPE"]["S"] == "file-scan":
                allowed.append(tool["TOOL_NAME"]["S"])
        return allowed

    # def cross_account_tools(self):
    #     allowed = []
    #     for tool in APPROVED_TOOLS["TOOL"]:
    #         if tool["TOOL_TYPE"] == "cross-account":
    #             allowed.append(tool["TOOL_NAME"])
    #     return allowed

    def all_tools(self):
        allowed = []
        sorted_tools = sorted(self.tools_allowed, key=lambda i: i["TOOL_NAME"]["S"])
        for tool in sorted_tools:
            my_key = {
                "TOOL_NAME": tool["TOOL_NAME"],
                "TOOL_TYPE": tool["TOOL_TYPE"],
            }
            response = self.dynamo_client.get_item(
                TableName=self.table_name, Key=my_key
            )
            allowed.append(response["Item"])
        return allowed

    # Get keys in DynamoDB table
    @staticmethod
    def build_keys(table_name):
        dynamo_client = open_session()
        response = load_keys(dynamo_client[0], table_name)
        return response

    @staticmethod
    def get_images(server_redis):
        image_list = []
        try:
            tool_details = server_redis.get("TOOL_DETAIL")
            for tool in tool_details:
                image_list.append(
                    {tool["TOOL_NAME"]["S"]: tool["TOOL_META"]["M"]["IMG_NAME"]["S"]}
                )
            return image_list
        except Exception:
            return image_list

    @staticmethod
    def tools_of_type(type, server_redis):
        tools_allowed = server_redis.get("TOOL_DETAIL")
        return_tools = {}
        if type.lower() == "multiscan":
            for tool in tools_allowed:
                if tool["MULTISCAN"]["S"] == "true":
                    return_tools[tool["TOOL_NAME"]["S"]] = tool["TOOL_META"]["M"][
                        "DESCRIPTION"
                    ]["S"]
        else:
            for tool in tools_allowed:
                if tool["TOOL_TYPE"]["S"] == type:
                    return_tools[tool["TOOL_NAME"]["S"]] = tool["TOOL_META"]["M"][
                        "DESCRIPTION"
                    ]["S"]
        return return_tools


if __name__ == "__main__":
    current_tool = "prowler"
    try:
        tmp_var = Tools(current_tool)
        # print(tmp_var.job_input_bucket)
        # print(tmp_var.job_output_bucket)
        # print(tmp_var.job_definition)
        # print(tmp_var.job_queue)
        # print(tmp_var.job_role)
        # print(tmp_var.tool_meta)
        # print(tmp_var.scan_tools())
        # print(tmp_var.cross_account_tools())
        print(tmp_var.all_tools())
    except AttributeError as err:
        print(
            f"The tool {current_tool} does not exist or is missing an attribute: {err}"
        )
