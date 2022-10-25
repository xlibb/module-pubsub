// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/lang.runtime;
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new();
    map<stream<any, error?>> receivers = {};
    string[] names = ["Mike", "Kim", "Jimmy"];

    foreach string name in names {
        receivers[name] = check pubsub.subscribe("topic");
    }
    string[] news = check getNews();

    worker A {
        foreach string data in news {
            error? publish = pubsub.publish("topic", data);
            if publish is error {
                io:println(publish);
            }
            runtime:sleep(5);
        }
        pubsub:Error? gracefulShutdown = pubsub.gracefulShutdown();
        if gracefulShutdown is pubsub:Error {
            io:println(gracefulShutdown);
        }
    }

    worker B {
        foreach int i in 0 ..< 3 {
            foreach string key in receivers.keys() {
                if i == 1 && key == "Mike" {
                    error? close = receivers.get(key).close();
                    io:print(close);
                }
                record {|any value;|}|error? next = receivers.get(key).next();
                if next !is error? {
                    io:println(key, ": ", next.value);
                }
            }
            io:println("..............................");
        }
    }
}
