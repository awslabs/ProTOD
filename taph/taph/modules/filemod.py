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
from datetime import datetime, timedelta


def _fix_string(var):
    string_fix = '"' + var + '"'
    return string_fix


def file_mod(filename, last_file_date):
    days_in_future = 14
    today = datetime.today()
    current_date = str(datetime(today.year, today.month, today.day).date())
    future_date = str((datetime.now() + timedelta(days=days_in_future)).date())

    if last_file_date and last_file_date == current_date:
        return False
    elif not last_file_date:
        last_file_date = "2020-01-31"

    with open(filename, "r", encoding="utf-8") as file:
        data = file.read()
        data = data.replace(_fix_string(last_file_date), _fix_string(future_date))
    with open(filename, "w", encoding="utf-8") as file:
        file.write(data)
    last_file_date = current_date
    return last_file_date
