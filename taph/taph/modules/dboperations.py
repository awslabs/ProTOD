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


def open_session():
    fn_session = boto3.session.Session()
    region = fn_session.region_name
    dynamo = fn_session.client("dynamodb", region_name=region)

    return dynamo, region


def validate_operation(query_output):
    if query_output["ResponseMetadata"]["HTTPStatusCode"] != 200:
        return -1


def load_keys(dbclient, table_name):
    tools = dbclient.scan(TableName=table_name, ProjectionExpression="TOOL_NAME, TOOL_TYPE")
    if validate_operation(tools) == -1:
        print("No tools found in DynamoDB table " + table_name)
    results = tools["Items"]
    while "LastEvaluatedKey" in tools:
        tools = dbclient.scan(
            TableName=table_name,
            ProjectionExpression="TOOL_NAME, TOOL_TYPE",
            ExclusiveStartKey=tools["LastEvaluatedKey"],
        )
        results.extend(tools["Items"])
    return results


def empty_table(dbclient, table_name):
    dbtable = boto3.resource("dynamodb").Table(table_name)
    keys = dbclient.scan(TableName=table_name, ProjectionExpression="TOOL_NAME, TOOL_TYPE")
    results = keys["Items"]
    if keys is not None:
        for key in results:
            # print(key["TOOL_NAME"])
            dbtable.delete_item(
                Key={
                    "TOOL_NAME": key["TOOL_NAME"]["S"],
                    "TOOL_TYPE": key["TOOL_TYPE"]["S"],
                }
            )
