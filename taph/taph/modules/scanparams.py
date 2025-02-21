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
from flask import request, session
from modules.simplyred import RedisClient
from modules.tools import Tools


def _user_tags() -> str:
    remote_addr = ""
    if "HTTP_X_REAL_IP" in request.headers:
        remote_addr = request.headers.getlist("HTTP_X_REAL_IP")[0].rpartition(" ")[-1]
    elif "X-Forwarded-For" in request.headers:
        remote_addr = request.headers.getlist("X-Forwarded-For")[0].rpartition(" ")[-1]
    else:
        remote_addr = request.remote_addr or "untrackable"
    return remote_addr


def _get_redis_entry(session, server_redis):
    redis_entries = {
        "user_sub": session["sub"].replace("-", ""),
        "username": session["username"],
        "sqs_queue": server_redis.get("SQS_QUEUE"),
        "folder": session["SESSION_ID"],
    }
    return redis_entries


def set_env(
    session,
    server_redis,
    t,
    external_id="",
    external_bucket="",
    role_arn="",
    both_buckets="",
    ai_prompt="",
):
    redis_settings = _get_redis_entry(session, server_redis)
    environment_list = [
        {"name": "FOLDER", "value": redis_settings["folder"]},
        {"name": "USER_SUB", "value": redis_settings["user_sub"]},
        {"name": "USERNAME", "value": redis_settings["username"]},
        {"name": "SQS_QUEUE", "value": redis_settings["sqs_queue"]},
        {"name": "TOOL_NAME", "value": t.tool_name},
        {"name": "JOB_OUTPUT_BUCKET", "value": t.job_output_bucket},
        {"name": "JOB_INPUT_BUCKET", "value": t.job_input_bucket},
        {"name": "EXTERNAL_ID", "value": external_id},
        {"name": "EXTERNAL_BUCKET", "value": external_bucket},
        {"name": "ROLE_ARN", "value": role_arn},
        {"name": "BOTH_BUCKETS", "value": both_buckets},
        {"name": "AI_PROMPT", "value": ai_prompt},
    ]
    return environment_list


def fn_submit_job(
    fn_session, job_name, job_queue, job_definition, container_overrides, depends_on=[]
):
    job_tags = _user_tags()
    tag_dict = {"IPAddress": job_tags}
    client = fn_session.client("batch")
    response = client.submit_job(
        jobName=job_name,
        jobQueue=job_queue,
        jobDefinition=job_definition,
        containerOverrides=container_overrides,
        dependsOn=depends_on,
        tags=tag_dict,
    )
    return response
