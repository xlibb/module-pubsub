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

import ballerina/lang.runtime;
import ballerina/test;

@test:Config {
    groups: ["pubsub"]
}
function testPubSub() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    json expectedValue = {
        hello: "World"
    };
    stream<json, error?> subscribe = check pubsub.subscribe(topicName, 10);
    check pubsub.publish(topicName, expectedValue.cloneReadOnly(), 5);
    record {|json value;|}? msg = check subscribe.next();
    json actualValue = (<record {|json value;|}>msg).value;
    test:assertEquals(actualValue, expectedValue);
}

@test:Config {
    groups: ["pubsub"]
}
function testGracefulShutdown() returns error? {
    PubSub pubsub = new();
    stream<string, error?> subscribe = check pubsub.subscribe("topic");
    check pubsub.gracefulShutdown();
    record {|string value;|}|error? msg = subscribe.next();
    if msg !is () {
        test:assertFail(string `Expected "()", received ${(typeof msg).toString()}`);
    }

    string expectedValue = "Users cannot subscribe to a closed PubSub";
    stream<string, error?>|Error new_subscriber = pubsub.subscribe("topic");
    test:assertTrue(new_subscriber is Error);
    test:assertEquals((<Error>new_subscriber).message(), expectedValue);

    expectedValue = "Events cannot be published to a closed PubSub";
    Error? publish = pubsub.publish("topic", expectedValue);
    test:assertTrue(publish is Error);
    test:assertEquals((<Error>publish).message(), expectedValue);
}

@test:Config {
    groups: ["pubsub"]
}
function testForceShutdown() returns error? {
    PubSub pubsub = new();
    stream<string, error?> subscribe = check pubsub.subscribe("topic");
    check pubsub.forceShutdown();
    record {|string value;|}|error? msg = subscribe.next();
    if msg !is () {
        test:assertFail(string `Expected "()", received ${(typeof msg).toString()}`);
    }

    string expectedValue = "Users cannot subscribe to a closed PubSub";
    stream<string, error?>|Error new_subscriber = pubsub.subscribe("topic");
    test:assertTrue(new_subscriber is Error);
    test:assertEquals((<Error>new_subscriber).message(), expectedValue);

    expectedValue = "Events cannot be published to a closed PubSub";
    Error? publish = pubsub.publish("topic", expectedValue);
    test:assertTrue(publish is Error);
    test:assertEquals((<Error>publish).message(), expectedValue);
}

@test:Config {
    groups: ["pubsub"]
}
function testCreatingTopics() returns error? {
    PubSub pubsub = new(false);
    string topicName = "topic";
    Error? topic = pubsub.createTopic(topicName);
    test:assertTrue(topic !is Error);
    stream<string, error?> subscribe = check pubsub.subscribe(topicName);
    string expectedValue = "data";
    check pubsub.publish(topicName, expectedValue);
    record {|string value;|}? msg = check subscribe.next();
    string actualValue = (<record {|string value;|}>msg).value;
    test:assertEquals(actualValue, expectedValue);
}

@test:Config {
    groups: ["pubsub"]
}
function testAutoCreationTopicInPublishing() returns error? {
    PubSub pubsub = new(autoCreateTopics = true);
    string topicName = "topic";
    Error? publish = pubsub.publish(topicName, "data");
    test:assertTrue(publish !is Error);
    Error? topic = pubsub.createTopic(topicName);
    test:assertTrue(topic is Error);
    string expectedValue = string `Topic "${topicName}" already exists`;
    test:assertEquals((<Error>topic).message(), expectedValue);
}

@test:Config {
    groups: ["pubsub"]
}
function testWaitingInGracefulShutdown() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    stream<string, error?> subscriber = check pubsub.subscribe(topicName);
    string expectedValue = "data";
    Error? publish = pubsub.publish(topicName, expectedValue);
    test:assertTrue(publish !is Error);

    worker A {
        Error? close = pubsub.gracefulShutdown(5);
        test:assertTrue(close !is Error);
    }

    worker B {
        runtime:sleep(5);
        record {|string value;|}|error? next = subscriber.next();
        test:assertTrue(next !is error?);
        if next is record {|string value;|} {
            string actualValue = next.value;
            test:assertEquals(actualValue, expectedValue);
        }
    }
}
