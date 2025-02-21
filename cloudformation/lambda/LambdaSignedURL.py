# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import logging
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
sns_client = boto3.client("sns", region_name="${AWS::Region}")


def lambda_handler(event, context):
    bucket_name = event["Records"][0]["s3"]["bucket"]["name"]
    object_key = event["Records"][0]["s3"]["object"]["key"]
    object_sub = object_key.split("/")[0]
    tool_name = object_key.split("/")[1].split("-")[0]
    file_type = object_key.split(".")[-1]
    presigned_url = create_presigned_url(bucket_name, object_key)
    topic_arn = "arn:aws:sns:${AWS::Region}:${AWS::AccountId}:protod-" + object_sub
    subject = "ProTOD - " + tool_name + "." + file_type
    message = (
        "Click on the Presigned URL below to access your ProTOD output. The URL will expire in 7 days.\n"
        + "Note that the URL may have been cut by your mail client. If so, copy and paste the whole URL in your browser.\n\n"
        + presigned_url
    )
    print("Publishing message to topic - " + topic_arn)
    publish_message(topic_arn, message, subject)
    update_topic_tag(topic_arn)
    # print ('Subject: ' + subject)
    # print (message)
    return presigned_url


def create_presigned_url(bucket_name, object_key, expiration=604800):
    s3_client = boto3.client("s3")
    try:
        response = s3_client.generate_presigned_url(
            "get_object", Params={"Bucket": bucket_name, "Key": object_key}, ExpiresIn=expiration
        )
    except ClientError as e:
        logging.error(e)
        return None
    return response


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


def update_topic_tag(topic_arn):
    current_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    sns_client.tag_resource(ResourceArn=topic_arn, Tags=[{"Key": "LastUsed", "Value": current_date}])
    return None
