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
import time

QSL_DEFAULT = 10  # Quota Maximum Scans Run Within Time Limit
QTL_DEFAULT = 60  # Quota Time Limit in Seconds


def _quota_setup(session):
    try:
        session["QUOTA_TIME_LIMIT"] = QTL_DEFAULT
        session["QUOTA_SCAN_LIMIT"] = QSL_DEFAULT
        session["QUOTA_TIME"] = time.time() - (2 * float(QTL_DEFAULT))
        session["QUOTA_SCAN"] = QSL_DEFAULT
    except Exception:
        return False
    return True


def _decrement_files(session, decrement):
    if session["QUOTA_SCAN_LIMIT"] > 0:
        if decrement:
            session.update({"QUOTA_SCAN_LIMIT": (session["QUOTA_SCAN_LIMIT"] - 1)})
        return True
    else:
        return False


def _quota_check(session, decrement=False):
    if not session.keys() & {
        "QUOTA_TIME_LIMIT",
        "QUOTA_SCAN_LIMIT",
        "QUOTA_TIME",
        "QUOTA_SCAN",
    }:
        response = _quota_setup(session)
        if response:
            return _quota_check(session)
        else:
            return False
    else:
        check_timer = time.time() - session["QUOTA_TIME"]
        if check_timer < QTL_DEFAULT:
            response = _decrement_files(session, decrement=decrement)
            if response:
                return True
        else:
            session.update({"QUOTA_TIME": time.time(), "QUOTA_SCAN_LIMIT": QSL_DEFAULT})
            return True


def gatekeeper(session, decrement=False):
    if not _quota_check(session, decrement=decrement):
        check_timer = session["QUOTA_TIME_LIMIT"] - (
            time.time() - session["QUOTA_TIME"]
        )
        time_remains = str(int(check_timer))
        message = f"Please wait to start another job. Your quota of {session['QUOTA_SCAN']} submissions in {session['QUOTA_TIME_LIMIT']} seconds has been exceeded. Please wait {time_remains} seconds."
        return message
    else:
        return False
