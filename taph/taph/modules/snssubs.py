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
from datetime import datetime

import boto3
from botocore.exceptions import ClientError
from flask import session


def aws_session(my_region):
    fn_session = boto3.session.Session(region_name=my_region)
    return fn_session


def list_topics(my_region) -> list:
    try:
        fn_session = aws_session(my_region)
        sns = fn_session.client("sns")
        topics = []
        response = sns.list_topics()
        topics.extend(response.get("Topics"))
        token = response.get("NextToken")
        while token:
            response = sns.list_topics(NextToken=token)
            topics.extend(response.get("Topics"))
            token = response.get("NextToken")
    except ClientError:
        raise
    else:
        return topics


def list_subscriptions_by_topic(topic, my_region):
    try:
        fn_session = aws_session(my_region)
        sns = fn_session.client("sns")
        subscriptions = []
        response = sns.list_subscriptions_by_topic(TopicArn=topic)
        subscriptions.extend(response.get("Subscriptions"))
        token = response.get("NextToken")
        while token:
            response = sns.list_subscriptions_by_topic(TopicArn=topic, NextToken=token)
            subscriptions.extend(response.get("Subscriptions"))
            token = response.get("NextToken")

    except ClientError:
        raise
    else:
        return subscriptions


def get_my_topic(sf_sub_name, my_region):
    topic_format = "protod-" + sf_sub_name
    topic_list = list_topics(my_region)
    sub_check = []
    response = ""
    for i in topic_list:
        if i["TopicArn"].endswith(topic_format):
            response = i["TopicArn"]
    if response:
        sub_check.append(response)
        sub_response = list_subscriptions_by_topic(response, my_region)
        if not sub_response:
            sub_check.append("SubNeeded")
        elif sub_response[0]["SubscriptionArn"] == "PendingConfirmation":
            sub_check.append("SubPending")
        else:
            sub_check.append("Subscribed")
    return sub_check


def create_topic(sf_sub_name, my_region):
    topic_format = "protod-" + sf_sub_name
    try:
        current_date = datetime.now().strftime("%Y-%m-%d")
        fn_session = aws_session(my_region)
        sns = fn_session.client("sns")
        topic = sns.create_topic(
            Name=topic_format,
            Attributes={
                "DisplayName": "ProTOD Notifications",
                "KmsMasterKeyId": "alias/aws/sns",
            },
            Tags=[
                {"Key": "CreationDate", "Value": current_date},
            ],
        )
    except ClientError:
        raise
    else:
        return topic


def subscribe_topic(sf_email, topic_arn, my_region):
    try:
        fn_session = aws_session(my_region)
        sns = fn_session.client("sns")
        topic = sns.subscribe(
            TopicArn=topic_arn,
            Protocol="email",
            Endpoint=sf_email,
            ReturnSubscriptionArn=True,
        )
    except ClientError:
        raise
    else:
        return topic


def process_topic(topic_check, sf_sub_name, sf_email, my_region):
    if not topic_check:
        new_topic = create_topic(sf_sub_name, my_region)
        return new_topic
    if topic_check[1] == "SubNeeded":
        return subscribe_topic(sf_email, topic_check[0], my_region)
    else:
        return topic_check
