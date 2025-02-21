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

#         - 'arn:aws:iam::aws:policy/SecurityAudit'
#        - 'arn:aws:iam::aws:policy/job-function/ViewOnlyAccess'

policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ds:ListAuthorizedApplications",
                "ec2:GetEbsEncryptionByDefault",
                "ecr:Describe*",
                "elasticfilesystem:DescribeBackupPolicy",
                "glue:GetConnections",
                "glue:GetSecurityConfiguration",
                "glue:SearchTables",
                "lambda:GetFunction",
                "s3:GetAccountPublicAccessBlock",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "ssm:GetDocument",
                "support:Describe*",
                "tag:GetTagKeys",
            ],
            "Resource": "*",
        }
    ],
}

client = boto3.client("iam")
response = client.simulate_custom_policy(
    PolicyInputList=[json.dumps(policy)],
    ActionNames=[
        "ds:ListAuthorizedApplications",
        "ec2:GetEbsEncryptionByDefault",
        "elasticfilesystem:DescribeBackupPolicy",
        "glue:GetConnections",
        "glue:GetSecurityConfiguration",
        "glue:SearchTables",
        "lambda:GetFunction",
        "s3:GetAccountPublicAccessBlock",
        "shield:DescribeProtection",
        "shield:GetSubscriptionState",
        "ssm:GetDocument",
        "tag:GetTagKeys",
    ],
)

evaluation_list = []
for results in response["EvaluationResults"]:
    evaluation_list.append(
        {
            results["EvalActionName"]: results["EvalDecision"],
        }
    )

for dict in evaluation_list:
    for k in dict:
        print(k + ": " + dict[k])
