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
from datetime import datetime


def fix_time(time_string) -> str:
    return datetime.utcfromtimestamp(int(time_string) / 1000.0).strftime(
        "%Y-%m-%d %H:%M:%S"
    )


def get_batch_jobs(fn_session, my_region, my_job):
    job_details_list = []
    client = fn_session.client("batch", region_name=my_region)
    response = client.describe_jobs(jobs=[my_job])
    resp = response["jobs"][0]
    log_stream_name = resp["attempts"][-1]["container"]["logStreamName"]
    for item in resp["container"]["environment"]:
        if item["name"] == "TOOL_NAME":
            tool_name = item["value"]
        else:
            tool_name = "Unknown"
    job_details_list.append(
        {
            "toolName": tool_name,
            "jobName": resp["jobName"],
            "jobId": resp["jobId"],
            "status": resp["status"],
            "createdAt": fix_time(resp["createdAt"]),
            "startedAt": fix_time(resp["startedAt"]),
            "stoppedAt": fix_time(resp["stoppedAt"]),
        }
    )
    return {"logStreamName": log_stream_name, "ResultList": job_details_list}


def process_stream(streams):
    my_output = []
    my_output.append("<table class='table table-striped'><thead class='thead-light'>")
    my_output.append(
        "<tr><th scope='col'>Timestamp</th><th scope='col'>Message</th></tr></thead>"
    )
    for stream in streams:
        for key, val in stream.items():
            if key == "timestamp":
                key_str = "<tr><td>" + fix_time(val) + "</td>"
                my_output.append(key_str)
            elif key == "message":
                key_str = "<td>" + val + "</td></tr>"
                my_output.append(key_str)
            else:
                pass
    my_output.append("</table>")
    return "\n".join(my_output)


def get_log_stream(fn_session, logstream):
    client = fn_session.client("logs")
    response = client.get_log_events(
        logGroupName="/aws/batch/job", logStreamName=logstream, startFromHead=True
    )
    return process_stream(response["events"])
