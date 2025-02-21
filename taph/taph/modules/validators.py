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
import re


def form_validator(external_id, bucket, role_arn, both_buckets):
    validation = []
    if external_id and bucket and role_arn:
        p = PatternMatch()
        return p.pattern_validate(
            external_id=external_id, bucket=bucket, role_arn=role_arn
        )
    elif both_buckets:
        validation.append(
            "Both buckets toggle cannot be used without all information entered."
        )
        return validation
    else:
        if external_id or bucket or role_arn:
            if not external_id:
                validation.append(
                    "External Id cannot be blank when using a custom bucket."
                )
            if not bucket:
                validation.append("Bucket cannot be blank when using a custom bucket.")
            if not role_arn:
                validation.append(
                    "Role ARN cannot be blank when using a custom bucket."
                )
            return validation
        return True


def prowler_validate(
    sf_account,
    sf_role_name,
    sf_external_id,
    sf_bucket_role_arn,
    sf_custom_bucket,
    sf_bucket_external_id,
    sf_both_buckets,
):
    validation = []
    if (
        sf_bucket_role_arn
        or sf_custom_bucket
        or sf_bucket_external_id
        or sf_both_buckets
    ):
        evaluate = form_validator(
            sf_bucket_external_id, sf_custom_bucket, sf_bucket_role_arn, sf_both_buckets
        )
        if not isinstance(evaluate, bool):
            validation.append(evaluate)
    p = PatternMatch()
    for account in sf_account:
        evaluate = p.pattern_validate(account=account)
        if not isinstance(evaluate, bool):
            validation.append(evaluate)
    evaluate = p.pattern_validate(role_name=sf_role_name, external_id=sf_external_id)
    if not isinstance(evaluate, bool):
        validation.append(evaluate)
    if validation:
        return validation
    else:
        return True


class PatternMatch:
    def __init__(self):
        self.pattern_external_id = re.compile(r"^[0-9A-Za-z=,.@:\/\-]{10,256}$")
        self.pattern_bucket = re.compile(
            "(?!(^xn--|.+-s3alias$))^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
        )
        self.pattern_role_arn = re.compile(
            r"^arn:(aws|aws-cn|aws-us-gov):iam::\d{12}:(?:role\/[A-Za-z0-9\/\-]+)$"
        )
        self.pattern_role_name = re.compile(r"^[A-Za-z0-9\/\-]+$")
        self.pattern_account = re.compile(r"^\d{12}$")

    def pattern_validate(self, **kwargs):
        patterns = []
        for k, v in kwargs.items():
            if v and k == "bucket":
                if not self.pattern_bucket.match(v):
                    patterns.append(f"The bucket name {v} is not valid.")
            elif v and k == "external_id":
                if not self.pattern_external_id.match(v):
                    patterns.append(f"The external id {v} is not valid.")
            elif v and k == "role_arn":
                if not self.pattern_role_arn.match(v):
                    patterns.append(f"The role arn {v} is not valid.")
            elif v and k == "account":
                if not self.pattern_account.match(v):
                    patterns.append(f"The account {v} is not valid.")
            elif v and k == "role_name":
                if not self.pattern_role_name.match(v):
                    patterns.append(f"The role name {v} is not valid.")
            else:
                patterns.append("There vas a validation failure.")
        if patterns:
            return patterns
        else:
            return True
