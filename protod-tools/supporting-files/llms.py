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

MODEL_PARAMETERS = {
    "anthropic.claude": {
        "description": "Anthropic Claude is a large language model trained by Anthropic.",
        "model-ids": [
            "anthropic.claude-v1",
            "anthropic.claude-v2",
            "anthropic.claude-v2:1",
            "anthropic.claude-instant-v1",
            "anthropic.claude-3-sonnet-20240229-v1:0",
            "anthropic.claude-3-haiku-20240307-v1:0",
            "anthropic.claude-3-opus-20240229-v1:0",
            "anthropic.claude-3-5-sonnet-20240620-v1:0",
        ],
        "max_tokens": {
            "type": "int",
            "min": 0,
            "max": 4096,
            "model_default": 200,
            "class_default": 300,
            "increment": 1,
            "description": "Maximum number of tokens to generate in the response. Recommended max of 4000 for best performance.",
        },
        "temperature": {
            "type": "float",
            "min": 0.0,
            "max": 1.0,
            "model_default": 0.5,
            "class_default": 0.1,
            "increment": 0.1,
            "description": "Higher is more creative in responses. Lower is more predictable.",
        },
        "top_p": {
            "type": "float",
            "min": 0.0,
            "max": 1.0,
            "model_default": 1.0,
            "class_default": 0.9,
            "increment": 0.1,
            "description": "Below 1 means model ignores less probable responses.",
        },
        "top_k": {
            "type": "int",
            "min": 0,
            "max": 100_000_000,
            "model_default": 250,
            "class_default": 250,
            "increment": 1,
            "description": "Number of token choices the model uses to generate the next token.",
        },
        "http_accept": {
            "type": "string",
            "model_default": "*/*",
            "class_default": "*/*",
            "description": "HTTP Accept header value.",
            "valid_values": ["*/*", "application/json"],
        },
        "http_content_type": {
            "type": "string",
            "model_default": "application/json",
            "class_default": "application/json",
            "description": "HTTP Content-Type header value.",
            "valid_values": ["application/json"],
        },
        "question": {
            "type": "string",
            "model_default": "N/A",
            "class_default": "Summarize the following text: ",
            "description": "Question to ask the model.",
        },
        "model_specifics": {
            "roles_allowed": ["user", "assistant"],
            "types_allowed": ["text", "image"],
            "image_formats": ["png", "jpg", "jpeg", "gif", "webp"],
        },
    }
}
