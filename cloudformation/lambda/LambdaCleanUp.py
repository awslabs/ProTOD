# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import logging
import sys
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

AWS_REGION = ""
AWS_ACCOUNT = ""


def get_topics():
    response = sns_client.list_topics()
    topics = response["Topics"]
    while response.get("NextToken", None) is not None:
        response = sns_client.list_topics(NextToken=response.get("NextToken"))
        topics = topics + response["Topics"]
    return topics


def delete_old_topics(topics):
    for topic in topics:
        topicArn = topic["TopicArn"]
        mystring = "arn:aws:sns:" + AWS_REGION + ":" + AWS_ACCOUNT + ":protod-"
        if topicArn.startswith(mystring):
            tags = sns_client.list_tags_for_resource(ResourceArn=topicArn)
            if tags["Tags"]:
                for tag in tags["Tags"]:
                    if tag["Key"] == "LastUsed":
                        last_updated_date = tag["Value"]
                        try:
                            bool(datetime.strptime(last_updated_date, "%Y-%m-%d"))
                        except ValueError as e:
                            print(f"Topic tag LastUsed is not in the right format giving error {e}")
                            sys.exit(1)
                        python_date = datetime.strptime(last_updated_date, "%Y-%m-%d")
                        delta_days = (datetime.now() - python_date).days
                        if delta_days > alert_days and delta_days <= retain_days:
                            subscriptions = sns_client.list_subscriptions_by_topic(TopicArn=topicArn)
                            if subscriptions["Subscriptions"]:
                                subject = "ProTOD - SNS Topic Scheduled Deletion"
                                message = (
                                    "Your ProTOD SNS topic is "
                                    + str(delta_days)
                                    + " days old and will be deleted from the system at the 1 year mark as part of our resource frugality process. "
                                    + "Once deleted, you will be able to re-create the topic by logging into ProTOD again"
                                )
                                print("Notifying " + topicArn)
                                publish_message(topicArn, message, subject)
                        if delta_days > retain_days:
                            subscriptions = sns_client.list_subscriptions_by_topic(TopicArn=topicArn)
                            if subscriptions["Subscriptions"]:
                                subject = "ProTOD - SNS Topic Deleted"
                                message = (
                                    "Your ProTOD SNS topic is "
                                    + str(delta_days)
                                    + " days old and it has been deleted. "
                                    + "You will be able to re-create the topic by logging into ProTOD again"
                                )
                                print("Notifying " + topicArn)
                                publish_message(topicArn, message, subject)
                            print("Deleting " + topicArn)
                            sns_client.delete_topic(TopicArn=topicArn)


def publish_message(topic_arn, message, subject):
    try:
        response = sns_client.publish(
            TopicArn=topic_arn,
            Message=message,
            Subject=subject,
        )["MessageId"]
    except ClientError:
        logger.exception("Could not publish message to the topic.")
        raise
    else:
        return response


alert_days = 355
retain_days = 365
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()
sns_client = boto3.client("sns", region_name=AWS_REGION)
topics = get_topics()
delete_old_topics(topics)
