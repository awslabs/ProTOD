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
import ast
import json
import unittest

import valkey as redis


class RedisClient:
    def __init__(self, host, port, db):
        self.host = host
        self.port = port
        self.db = db
        self.client = redis.StrictRedis(
            host=self.host, port=self.port, db=self.db, decode_responses=True
        )

    def set(self, key, value):
        in_type = type(value)
        data_type = '"S"'
        fixup = True
        if in_type is dict:
            value = json.dumps(value)
            data_type = '"M"'
            fixup = False
        if in_type is list:
            value = str(value)
            data_type = '"SS"'
        if in_type is int:
            value = str(value)
            data_type = '"N"'
        if in_type is float:
            value = str(value)
            data_type = '"F"'
        if in_type is bool:
            value = str(value)
            data_type = '"B"'
        if fixup:
            # fmt: off
            set_type = "{" + data_type + ": \"" + value + "\"}"
            # fmt: on
        else:
            set_type = "{" + data_type + ": " + value + "}"
        self.client.set(key, set_type)

    def get(self, key):
        try:
            json_object = json.loads(self.client.get(key))
            for key_data in json_object.keys():
                if key_data == "S":
                    response = json_object[key_data]
                elif key_data == "M":
                    response = json_object[key_data]
                elif key_data == "SS":
                    response = ast.literal_eval(json_object[key_data])
                elif key_data == "N":
                    response = int(json_object[key_data])
                elif key_data == "F":
                    response = float(json_object[key_data])
                elif key_data == "B":
                    response = bool(json_object[key_data])
                else:
                    response = json_object[key_data]
            return response
        except TypeError:
            return None

    def exists(self, key):
        return self.client.exists(key)

    def delete(self, key):
        self.client.delete(key)

    def keys(self, pattern="*"):
        return self.client.keys(pattern)

    def flush_db(self):
        self.client.flushdb()


class RedisClientTest(unittest.TestCase):
    def setUp(self):
        self.redis_client = RedisClient("localhost", 6379, 1)

    def test_flush_db(self):
        self.redis_client.set("test", "test")
        self.assertEqual(self.redis_client.get("test"), "test")
        self.redis_client.flush_db()
        self.assertEqual(self.redis_client.get("test"), None)
        print(" Flushed DB " + str(self.redis_client.keys()))

    def test_set_get_delete_json(self):
        self.redis_client.set("test_json", {"test": "test"})
        self.assertEqual(self.redis_client.get("test_json"), {"test": "test"})
        self.redis_client.delete("test_json")
        self.assertEqual(self.redis_client.get("test_json"), None)
        print(" Set Get and Delete JSON " + str(self.redis_client.keys()))

    def test_get_all_json_keys(self):
        self.redis_client.set("test_json", {"test": "test"})
        self.assertEqual(self.redis_client.keys(), ["test_json"])
        self.redis_client.delete("test_json")
        print(" Deleted JSON " + str(self.redis_client.keys()))

    def test_get_all_keys(self):
        self.redis_client.set("test", "test")
        self.assertEqual(self.redis_client.keys(), ["test"])
        self.redis_client.delete("test")
        print(" Deleted Key " + str(self.redis_client.keys()))

    def test_set_get_delete(self):
        self.redis_client.set("test", "test")
        self.assertEqual(self.redis_client.get("test"), "test")
        self.redis_client.delete("test")
        self.assertEqual(self.redis_client.get("test"), None)
        print(" Set Get and Delete Key" + str(self.redis_client.keys()))

    def test_exists(self):
        self.redis_client.set("test", "test")
        self.assertEqual(self.redis_client.exists("test"), True)
        self.redis_client.delete("test")
        self.assertEqual(self.redis_client.exists("test"), False)
        print(" Key Exists " + str(self.redis_client.keys()))


if __name__ == "__main__":
    # unittest.main()

    # rc = RedisClient("localhost", 6379, 1)
    # rc.set("test", "test")
    # rc.set("test2", 123)
    # rc.set("test3", 123.123)
    # rc.set("test4", True)
    # rc.set("test5", [1, 2, 3])
    # rc.set("test_json", {"test": "test"})
    # print(rc.get("test"))
    # print(type(rc.get("test")))
    # print(rc.get("test2"))
    # print(type(rc.get("test2")))
    # print(rc.get("test3"))
    # print(type(rc.get("test3")))
    # print(rc.get("test4"))
    # print(type(rc.get("test4")))
    # print(rc.get("TOOL_DETAIL"))
    # print(rc.get("JWT_HEADER_NAME"))
    # print(rc.get("LAMBDA_JWT_ARN"))
    # print(rc.get("TOOLS_ALLOWED"))
    # print(rc.get("MY_REGION"))
    # print(rc.get("MULTISCAN_TOOLS"))
    # print(rc.get("MY_TOOL_TABLE"))
    # print(rc.get("SQS_QUEUE"))
    # print(type(rc.get("test5")))
    # print(rc.get("test_json"))
    # print(type(rc.get("test_json")))

    # rc.flush_db()

    client = redis.StrictRedis(
        host="localhost", port="6379", db="1", decode_responses=True
    )
    keys = client.keys("*")
    values = client.mget(keys)
    for i in range(len(keys)):
        print(keys[i], values[i])
