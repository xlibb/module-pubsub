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

import xlibb/pubsub;
import ballerina/test;

@test:Config {
    groups: ["pubsub", "examples", "news_alert"]
}
function testPubSub() returns error? {
    pubsub:PubSub pubsub = new();
    stream<any, error?> subscribe = check pubsub.subscribe("testTopic");
    string expectedValue = "data";
    check pubsub.publish("testTopic", expectedValue);
    record {|any value;|}? 'record = check subscribe.next();
    if 'record != () {
        test:assertEquals(expectedValue, <string>'record.value);
    }
}

@test:Config {
    groups: ["pubsub", "examples", "news_alert"]
}
function testGracefulCloseInPubSub() returns error? {
    pubsub:PubSub pubsub = new();
    check pubsub.gracefulShutdown();
    string expectedValue = "Events cannot be published to a closed PubSub.";
    error? publish = pubsub.publish("topic", "data");
    test:assertTrue(publish is error, "Assertion failed: Data is published to a closed PubSub.");
    if publish is error {
        test:assertEquals(expectedValue, publish.message());
    }
}
