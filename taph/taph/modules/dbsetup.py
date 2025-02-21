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
import base64
import json
import os
from pathlib import Path
from secretmgr import get_secret
from dboperations import open_session, validate_operation, empty_table


def fill_images(dbclient, table, img_dir):
    image_list = []
    for image in os.listdir(img_dir):
        if image.endswith("-logo.png"):
            my_tool = image.split("-")[0]
            file_path = img_dir + "/" + image
            with open(file_path, "rb") as img_file:
                img_string = base64.b64encode(img_file.read())
            image_list.append({my_tool: img_string.decode()})

    for logo in image_list:
        my_tool_name = list(logo.keys())[0]
        my_tool_query = dbclient.query(
            TableName=table,
            KeyConditionExpression="TOOL_NAME = :tool_name",
            ExpressionAttributeValues={
                ":tool_name": {"S": my_tool_name},
            },
        )
        if my_tool_query["Items"]:
            my_type = my_tool_query["Items"][0]["TOOL_TYPE"]
            # print(my_type)
            my_tool_update = dbclient.update_item(
                TableName=table,
                Key={
                    "TOOL_NAME": {"S": my_tool_name},
                    "TOOL_TYPE": my_type,
                },
                UpdateExpression="set TOOL_META.IMG_NAME=:img_name",
                ExpressionAttributeValues={
                    ":img_name": {
                        "S": logo[my_tool_name],
                    },
                },
                ReturnValues="UPDATED_NEW",
            )
            if validate_operation(my_tool_update) == -1:
                print("Failed to add image to " + my_tool_name)
        else:
            print("No tools found in DynamoDB table " + table)


if __name__ == "__main__":

    # Setup boto3 session
    dynamo_session, region = open_session()

    # Get DynamoDB table name from Secrets Manager
    ptod_key = get_secret("app/protod", region)
    ptod_key = json.loads(ptod_key)
    table_name = ptod_key["toolstable"]
    input_bucket = ptod_key["inputbucket"]
    output_bucket = ptod_key["outputbucket"]

    # Get content to fill table with
    dynamo_content = Path("../static/DynamoDB-content.txt").read_text()
    dynamo_content = dynamo_content.replace(
        "REPLACE-WITH-JOB-INPUT-BUCKET", input_bucket
    )
    dynamo_content = dynamo_content.replace(
        "REPLACE-WITH-JOB-OUTPUT-BUCKET", output_bucket
    )
    dynamo_content = json.loads(dynamo_content)

    # Check if the table is empty. If not, empty it.
    empty_table(dynamo_session, table_name)

    # Fill table
    for item in dynamo_content["TOOL"]:
        create_tool = dynamo_session.put_item(TableName=table_name, Item=item)
        if validate_operation(create_tool) == -1:
            failed_item = item["TOOL_NAME"]["S"]
            print("Failed to create item for " + failed_item)

    img_dir = "../static/images"
    fill_images(dynamo_session, table_name, img_dir)
