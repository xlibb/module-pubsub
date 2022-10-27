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

import ballerina/test;

@test:Config {
    groups: ["errors"]
}
function testPublishingToNonExistingTopic() returns error? {
    PubSub pubsub = new(autoCreateTopics = false);
    string topicName = "topic";
    string expectedValue = string `Topic "${topicName}" does not exist.`;
    Error? publish = pubsub.publish(topicName, "hello");
    test:assertTrue(publish is Error);
    test:assertEquals((<Error>publish).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testSubscribingToNonExistingTopic() returns error? {
    PubSub pubsub = new(autoCreateTopics = false);
    string topicName = "topic";
    string expectedValue = string `Topic "${topicName}" does not exist.`;
    stream<string, error?>|Error subscribe = pubsub.subscribe(topicName);
    test:assertTrue(subscribe is Error);
    test:assertEquals((<Error>subscribe).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testSubscribingToClosedPubSub() returns error? {
    PubSub pubsub = new(false);
    check pubsub.gracefulShutdown();
    stream<string, error?>|Error subscribe = pubsub.subscribe("topic");
    test:assertTrue(subscribe is Error);
    string expectedValue = "Users cannot subscribe to a closed PubSub.";
    test:assertEquals((<Error>subscribe).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testClosingStreams() returns error? {
    PubSub pubsub = new();
    string topic = "topic";
    stream<string, error?> newStream1 = check pubsub.subscribe(topic);
    stream<string, error?> newStream2 = check pubsub.subscribe(topic);
    check newStream2.close();
    check pubsub.publish(topic, "data");
    string expectedValue = "Events cannot be consumed after the stream is closed";
    record {|string value;|}|error? next = newStream2.next();
    test:assertTrue(next is error);
    test:assertEquals((<error>next).message(), expectedValue);
    record {|string value;|}? message = check newStream1.next();
    expectedValue = "data";
    string actualValue = (<record {|string value;|}>message).value;
    test:assertEquals(actualValue, expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testCreatingExistingTopics() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    check pubsub.createTopic(topicName);
    Error? topic = pubsub.createTopic(topicName);
    test:assertTrue(topic is Error);
    string expectedValue = string `Topic "${topicName}" already exists.`;
    test:assertEquals((<Error>topic).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testCreatingExistingTopicsToAutoCreateTopicsEnabledPubSub() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    check pubsub.publish(topicName, "event");
    Error? topic = pubsub.createTopic(topicName);
    test:assertTrue(topic is Error);
    string expectedValue = string `Topic "${topicName}" already exists.`;
    test:assertEquals((<Error>topic).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testCreatingTopicsInClosedPubSub() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    check pubsub.forceShutdown();
    Error? topic = pubsub.createTopic(topicName);
    test:assertTrue(topic is Error);
    string expectedValue = "Topics cannot be created in a closed PubSub.";
    test:assertEquals((<Error>topic).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testPublishingNullValuesToTopics() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    stream<string, error?>|Error subscriber = pubsub.subscribe(topicName);
    test:assertTrue(subscriber !is Error);
    Error? publish = pubsub.publish(topicName, ());
    test:assertTrue(publish is Error);
    string expectedValue = "Nil values cannot be published to a PubSub.";
    test:assertEquals((<Error>publish).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testClosingPubSubWithClosedStream() returns error? {
    PubSub pubsub = new();
    stream<string, error?> subscriberStream = check pubsub.subscribe("topic");
    check subscriberStream.close();
    Error? result = pubsub.forceShutdown();
    test:assertTrue(result is Error);
    string expectedMessage = "Failed to shut down the pubsub";
    Error pubsubError = <Error>result;
    test:assertEquals(pubsubError.message(), expectedMessage);
    error? cause = pubsubError.cause();
    test:assertTrue(cause is error);
    expectedMessage = "Closing of a closed pipe is not allowed.";
    test:assertEquals((<error>cause).message(), expectedMessage);
}

@test:Config {
    groups: ["errors"]
}
function testTimeoutErrorsInPubSub() returns error? {
    PubSub pubsub = new();
    string topicName = "topic";
    string expectedValue = "event";
    stream<string, error?> subscriber_1 = check pubsub.subscribe("topic", 0);
    stream<string, error?> subscriber_2 = check pubsub.subscribe("topic", 5);
    Error? publish = pubsub.publish(topicName, expectedValue, 1);
    test:assertTrue(publish is Error);
    string expectedError = "Failed to publish events to some subscribers.";
    test:assertEquals((<Error>publish).message(), expectedError);
    expectedError = "Operation has timed out.";
    test:assertEquals((<error>((<Error>publish).cause())).message(), expectedError);

    record {|string value;|}|error? event_stream_1 = subscriber_1.next();
    string actualValue = (<error>event_stream_1).message();
    test:assertEquals(actualValue, expectedError);

    record {|string value;|}? event_stream_2 = check subscriber_2.next();
    actualValue = (<record {|string value;|}>event_stream_2).value;
    test:assertEquals(actualValue, expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testClosingOfClosedPubSub() returns error? {
    PubSub pubsub = new();
    check pubsub.forceShutdown();
    Error? forceShutdown = pubsub.forceShutdown();
    test:assertTrue(forceShutdown is Error);
    string expectedValue = "Closing of a closed PubSub is not allowed.";
    test:assertEquals((<Error>forceShutdown).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testClosingOfGracefullyClosedPubSub() returns error? {
    PubSub pubsub = new();
    check pubsub.gracefulShutdown();
    Error? forceShutdown = pubsub.forceShutdown();
    test:assertTrue(forceShutdown is Error);
    string expectedValue = "Closing of a closed PubSub is not allowed.";
    test:assertEquals((<Error>forceShutdown).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testGracefullyClosingOfGracefullyClosedPubSub() returns error? {
    PubSub pubsub = new();
    check pubsub.gracefulShutdown();
    Error? forceShutdown = pubsub.gracefulShutdown();
    test:assertTrue(forceShutdown is Error);
    string expectedValue = "Closing of a closed PubSub is not allowed.";
    test:assertEquals((<Error>forceShutdown).message(), expectedValue);
}

@test:Config {
    groups: ["errors"]
}
function testGracefullyClosingOfClosedPubSub() returns error? {
    PubSub pubsub = new();
    check pubsub.forceShutdown();
    Error? forceShutdown = pubsub.gracefulShutdown();
    test:assertTrue(forceShutdown is Error);
    string expectedValue = "Closing of a closed PubSub is not allowed.";
    test:assertEquals((<Error>forceShutdown).message(), expectedValue);
}
