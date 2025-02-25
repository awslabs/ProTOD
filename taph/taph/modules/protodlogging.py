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
import logging


def log_debug_and_critical(func):
    def wrapper(*args, **kwargs):
        logger = logging.getLogger(func.__name__)
        logger.setLevel(logging.DEBUG)
        logger.debug("Entering function %s", func.__name__)
        result = func(*args, **kwargs)
        logger.critical("Result from %s: %s", func.__name__, result)
        return result

    return wrapper
