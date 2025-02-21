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
import time

import boto3
from llms import MODEL_PARAMETERS


class BedrockAi:
    """BedrockAi interacts with AWS Bedrock to run Anthropic Claude models.

    This class provides a simple interface to invoke Anthropic Claude models
    hosted on AWS Bedrock. It handles creating the API request body, invoking
    the model, and returning the raw API response.

    Key features:

    - Supports different Claude models like Claude 3 Sonnet, Claude 3 Haiku, etc.
    - Allows configuring Claude parameters like temperature, top_p, top_k etc.
    - Accepts text content, creates the prompt with context and invokes Claude
    - Returns raw Claude API response for further processing

    Usage:

    ```
    ai = BedrockAi()
    response = ai.invoke_ai("Some text content")
    ```

    The returned response contains the raw Claude API response and can be
    processed further to extract the generated text.
    """

    def __init__(
        self,
        model="anthropic.claude-3-5-sonnet-20240620-v1:0",
        max_tokens=MODEL_PARAMETERS["anthropic.claude"]["max_tokens"]["class_default"],
        http_accept=MODEL_PARAMETERS["anthropic.claude"]["http_accept"]["class_default"],
        http_content_type=MODEL_PARAMETERS["anthropic.claude"]["http_content_type"]["class_default"],
        temperature=MODEL_PARAMETERS["anthropic.claude"]["temperature"]["class_default"],
        top_p=MODEL_PARAMETERS["anthropic.claude"]["top_p"]["class_default"],
        top_k=MODEL_PARAMETERS["anthropic.claude"]["top_k"]["class_default"],
        question=MODEL_PARAMETERS["anthropic.claude"]["question"]["class_default"],
    ):
        self.model = model
        self.max_tokens = max_tokens
        self.http_accept = http_accept
        self.http_content_type = http_content_type
        self.temperature = temperature
        self.top_p = top_p
        self.top_k = top_k
        self.question = question
        self.bedrock_regions = [
            "ap-northeast-1",
            "ap-south-1",
            "ap-southeast-1",
            "ap-southeast-2",
            "ca-central-1",
            "eu-central-1",
            "eu-west-2",
            "eu-west-3",
            "sa-east-1",
            "us-east-1",
            "us-west-2",
        ]

    def _create_session(self):
        self.get_session = boto3.session.Session()
        return self.get_session

    def print_version(self):
        return self.model

    def _create_ai_body(self, content):
        _human_prompt = "\n\nHuman: "
        _ai_prompt = self.question
        _ai_prompt_body_string = content
        _assistant_prompt = "\n\nAssistant:"

        if self.model.startswith("anthropic.claude-3"):
            _prompt_string = f"{_ai_prompt} <text>{_ai_prompt_body_string}</text> "
            _body = json.dumps(
                {
                    "anthropic_version": "",
                    "max_tokens": self.max_tokens,
                    "messages": [
                        {
                            "role": "user",
                            "content": [{"type": "text", "text": _prompt_string}],
                        }
                    ],
                    "temperature": self.temperature,
                    "top_p": self.top_p,
                    "system": "",
                    "top_k": self.top_k,
                }
            )
        else:
            _prompt_string = f"{_human_prompt}{_ai_prompt} <text>{_ai_prompt_body_string}</text> {_assistant_prompt}"
            _body = json.dumps(
                {
                    "prompt": _prompt_string,
                    "temperature": self.temperature,
                    "top_p": self.top_p,
                    "top_k": self.top_k,
                    "max_tokens_to_sample": self.max_tokens,
                    "stop_sequences": ["\n\nHuman:"],
                }
            ).encode("utf-8")

        return _body

    def _content_verifier(self, content):
        prompt_size = len(content)
        if prompt_size > 10240000000:
            raise ValueError(f"Content is too large to be processed. Size: {prompt_size}")
        if not isinstance(content, str):
            raise ValueError("Content is not a string.")
        return True

    def _get_bedrock_client(self):
        method_session = self._create_session()
        region = method_session.region_name
        if region not in self.bedrock_regions:
            region = "us-east-1"
        return method_session.client(
            service_name="bedrock-runtime",
            region_name=region,
            endpoint_url=f"https://bedrock-runtime.{region}.amazonaws.com",
        )

    def invoke_ai(self, content):
        try:
            if self._content_verifier(content):
                bedrock_runtime = self._get_bedrock_client()
                _body = self._create_ai_body(content)
                response = bedrock_runtime.invoke_model(
                    contentType=self.http_content_type,
                    accept=self.http_accept,
                    modelId=self.model,
                    body=_body,
                )
                claude_stream = ""
                stream_text = ""
                response_body = response.get("body")
                for event in response_body:
                    claude_stream += event.decode("utf-8")
                resp_dict = json.loads(claude_stream)
                for response in resp_dict["content"]:
                    stream_text += response["text"]
                joined_stream = f"{stream_text} \n\nStop Reason: {resp_dict['stop_reason']} Stop: {resp_dict['stop_sequence']} Result: {resp_dict['usage']}"
                return joined_stream
        except Exception as e:
            raise e

    def invoke_ai_with_stream(self, content):
        bedrock_runtime = self._get_bedrock_client()
        _body = self._create_ai_body(content)
        response = bedrock_runtime.invoke_model_with_response_stream(modelId=self.model, body=_body)
        stream = response.get("body")
        stream_contents = []
        if stream:
            for event in stream:
                chunk = event.get("chunk")
                if chunk:
                    stream_contents.append(json.loads(chunk.get("bytes").decode()))
        if stream_contents:
            stream_text = ""
            stream_stop_reason = ""
            stream_stop = ""
            stream_result = ""
            for stream_obj in stream_contents:
                if stream_obj["type"] == "content_block_delta":
                    stream_text += f"{stream_obj['delta']['text']}"
                elif stream_obj["type"] == "content_block_start":
                    stream_text += f"{stream_obj['content_block']['text']}"
                elif stream_obj["type"] == "message_delta":
                    stream_stop_reason = stream_obj["delta"]["stop_reason"]
                    stream_stop = stream_obj["delta"]["stop_sequence"]
                elif stream_obj["type"] == "message_stop":
                    stream_result = stream_obj["amazon-bedrock-invocationMetrics"]
            joined_stream = (
                f"{stream_text} \n\nStop Reason: {stream_stop_reason} Stop: {stream_stop} Result: {stream_result}"
            )
            return joined_stream

        else:
            return None


if __name__ == "__main__":
    import argparse
    import os

    def scan_directory(directory, extensions):
        file_types = [".py", ".sh", ".ts", ".yaml", ".json", ".yml"]
        if extensions:
            extensions = [word.strip() for word in extensions.split(",")]
            print(f"Adding file extensions: {extensions} to scan list.")
            file_types = list(set(file_types + extensions))
        file_list = []

        for root, dirs, files in os.walk(directory):
            for file in files:
                file_test = file.lower()
                if file_test.endswith(tuple(file_types)):
                    file_list.append(os.path.join(root, file))

        return file_list

    def set_options(ai, args):
        try:
            allowed_text = ["http_accept", "http_content_type"]
            allowed_float = ["temperature", "top_p", "top_k"]
            allowed_int = ["max_tokens"]
            for setting in allowed_text:
                if getattr(args, setting):
                    setattr(ai, setting, getattr(args, setting))
            for setting in allowed_float:
                if getattr(args, setting):
                    setattr(ai, setting, float(getattr(args, setting)))
            for setting in allowed_int:
                if getattr(args, setting):
                    setattr(ai, setting, int(getattr(args, setting)))
            return ai
        except Exception as e:
            raise e

    def main_func():
        parser = argparse.ArgumentParser(description="File Scan with Generative AI.")
        parser.add_argument(
            "-a",
            "--http-accept",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['http_accept']['description']}  (optional)",
        )
        parser.add_argument(
            "-c",
            "--http-content-type",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['http_content_type']['description']}  (optional)",
        )
        parser.add_argument(
            "-k",
            "--top-k",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['top_k']['description']} (optional)",
        )
        parser.add_argument(
            "-m",
            "--model",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['description']}  (optional)",
        )
        parser.add_argument(
            "-p",
            "--top-p",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['top_p']['description']}  (optional)",
        )
        parser.add_argument(
            "-q",
            "--question",
            help=f"{MODEL_PARAMETERS['anthropic.claude']['question']['description']}  (optional)",
        )
        parser.add_argument(
            "-x",
            "--max-tokens",
            help="0-4096 Recommended max of 4000 for best performance (Model default 200) (optional)",
        )
        parser.add_argument(
            "-t",
            "--temperature",
            help="0.0-1.0 Higher is more creative in responses (Model default 0.5) (optional)",
        )
        parser.add_argument(
            "-s",
            "--stream",
            help="Use BedRock Streaming response instead of the default AI submission. (optional)",
            action="store_true",
        )
        parser.add_argument(
            "-e",
            "--extensions",
            help='Create a comma separated list of file extensions to check. (Default: ".py, .sh, .ts, .yaml, .json")',
        )
        parser.add_argument(
            "-v",
            "--version",
            action="version",
            version="%(prog)s anthropic.claude-3-5-sonnet-20240620-v1:0",
            help="Print the Bedrock LLM and version of the tool and exit.",
        )
        parser.add_argument("file", help="File to scan or directory to scan")
        args = parser.parse_args()
        file_to_scan = args.file
        if not file_to_scan:
            print("No file provided. Exiting...")
            exit()

        if os.path.isdir(file_to_scan):
            target_files = scan_directory(file_to_scan, args.extensions)
            if len(target_files) > 50:
                print("Too many files in this batch. Exiting.")
                exit()
        else:
            target_files = [file_to_scan]
        try:
            ai = BedrockAi()
            ai = set_options(ai, args)
            content_add = ""
            completion = ""
            for file in target_files:
                print(f"Processing file {file}...")
                with open(file, "r", encoding="utf-8") as f:
                    content = f.read()
                    content_add += f"{content_add}<filename>{file}</filename>\n{content}\n\n"
            if args.question:
                ai.question = f"{args.question} Ensure the filename is listed in the report as appears between the <filename></filename> tags. Ensure the report is in Markdown format."
            start = time.time()
            if not args.stream:
                completion = ai.invoke_ai(json.dumps(content_add))
            else:
                completion = ai.invoke_ai_with_stream(json.dumps(content_add))
            end = time.time()
            print(completion)
            print(f"Claude Model {ai.model} execution time: {int(end - start)} seconds.")
        except Exception as e:
            print(f"Couldn't invoke Anthropic Claude with error: {e}")


main_func()
