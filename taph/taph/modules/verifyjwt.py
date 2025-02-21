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
import base64
import json

import boto3
import jwt
from flask import flash, redirect, request, url_for
from modules.simplyred import RedisClient


def __open_session():
    fn_session = boto3.session.Session()
    region = fn_session.region_name
    new_client = fn_session.client("lambda", region_name=region)

    return new_client


def __get_pub_key_from_lambda(kid, lambda_jwt_arn):
    client = __open_session()
    payload = json.dumps({"kid": kid}, indent=2).encode("utf-8")
    response = client.invoke(FunctionName=lambda_jwt_arn, Payload=payload)
    our_response = json.loads(response["Payload"].read().decode())
    return our_response


def b64(my_object, op):
    if op == "e":
        return_string = base64.b64encode(my_object.encode()).decode()
        print(return_string)
        print(type(return_string))
        return return_string
    if op == "d":
        return_string = base64.b64decode(my_object).decode()
        print(return_string)
        print(type(return_string))
        return return_string


def verify_jwt(token, server_redis, renew=False):
    try:
        lambda_jwt_arn = server_redis.get("LAMBDA_JWT_ARN")
        token_header = jwt.get_unverified_header(token)
        kid = token_header["kid"]
        alg = token_header["alg"]
        if server_redis.exists("JWT_PUB_KEY_CACHE") and not renew:
            encoded_pub_key = server_redis.get("JWT_PUB_KEY_CACHE")
            pub_key = b64(encoded_pub_key, "d")
        else:
            pub_key = __get_pub_key_from_lambda(kid, lambda_jwt_arn)
            encoded_pub_key = b64(pub_key, "e")
            server_redis.set("JWT_PUB_KEY_CACHE", encoded_pub_key)
        if not isinstance(pub_key, str):
            return pub_key
        else:
            payload = jwt.decode(token, pub_key, alg)
            return True
    except Exception as e:
        if not renew:
            verify_jwt(token, server_redis, renew=True)
        errors = [e]
        return errors


def decode_jwt(session, server_redis):
    full_jwt = request.headers.getlist(server_redis.get("JWT_HEADER_NAME"))
    response = verify_jwt(full_jwt[0], server_redis, renew=False)
    if not isinstance(response, bool):
        flash(response, "danger")
        return redirect(url_for("index"))
    try:
        session["email"]
    except KeyError:
        encoded_jwt = full_jwt[0].split(".")[1]
        decoded_jwt_headers = base64.b64decode(encoded_jwt)
        jwt_dict = json.loads(decoded_jwt_headers)
        for key in jwt_dict:
            session[key] = jwt_dict[key]
