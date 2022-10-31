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

import ballerina/jballerina.java;
import ballerina/lang.runtime;
import xlibb/pipe;

# An Events Transmission Model with Publish/Subscribe APIs.
public class PubSub {
    private map<pipe:Pipe[]> topics;
    private boolean isClosed;
    private boolean autoCreateTopics;
    private pipe:Pipe pipe;
    private final pipe:Timer timer;

    # Creates a new `pubsub:PubSub` instance.
    #
    # + autoCreateTopics - To enable/disable auto creation of the non-existing topics when publishing/subscribing
    public isolated function init(boolean autoCreateTopics = true) {
        self.topics = {};
        self.isClosed = false;
        self.autoCreateTopics = autoCreateTopics;
        self.pipe = new(0);
        self.timer = new;
    }

    # Publishes events into a topic of the PubSub. That will be broadcast to all the subscribers of that topic.
    #
    # + topicName - The name of the topic which is used to publish events
    # + event - Event that needs to be published to PubSub. Can be `any` type
    # + timeout - The maximum waiting period to hold events. Set the timeout to `-1` to wait without a time limit.
    # + return - Returns `()` if event is successfully published. Otherwise, returns a `pubsub:Error`
    public function publish(string topicName, any event, decimal timeout = 30) returns Error? {
        if self.isClosed {
            return error Error("Events cannot be published to a closed PubSub");
        }
        if event == () {
            return error Error("Nil values cannot be published to a PubSub");
        }
        if !self.topics.hasKey(topicName) {
            if !self.autoCreateTopics {
                return error Error(string `Topic "${topicName}" does not exist`);
            }
            check self.createTopic(topicName);
        }
        pipe:Pipe[] pipes = self.topics.get(topicName);
        check self.produceAll(pipes, event, timeout, topicName);
    }

    private function produceAll(pipe:Pipe[] pipes, any event, decimal timeout, string topicName) returns Error? {
        pipe:Pipe[] removedPipes = [];
        future<pipe:Error?>[] waitingQueue = [];
        foreach pipe:Pipe pipe in pipes {
            if !pipe.isClosed() {
                future<pipe:Error?> asyncValue = start self.produceEvents(pipe, event, timeout);
                waitingQueue.push(asyncValue);
            } else {
                removedPipes.push(pipe);
            }
        }
        Error? unsubscribeResult = self.unsubscribeClosedPipes(removedPipes, topicName);
        check self.waitForProduceCompletion(waitingQueue);
        return unsubscribeResult;
    }

    private isolated function produceEvents(pipe:Pipe pipe, any event, decimal timeout) returns pipe:Error? {
        check pipe.produce(event, timeout);
    }

    private isolated function waitForProduceCompletion(future<pipe:Error?>[] waitingQueue) returns Error? {
        pipe:Error? pipeError = ();
        foreach future<pipe:Error?> asyncValue in waitingQueue {
            pipe:Error? produce = wait asyncValue;
            if produce is pipe:Error {
                pipeError = produce;
            }
        }
        if pipeError != () {
            return error Error("Failed to publish events to some subscribers", pipeError);
        }
    }

    private isolated function unsubscribeClosedPipes(pipe:Pipe[] removedPipes, string topicName) returns Error? {
        foreach pipe:Pipe pipe in removedPipes {
            check self.unsubscribe(topicName, pipe);
        }
    }

    # Subscribes to a topic in the PubSub. The subscriber will receive the events published into that topic.
    # Every subscriber will receive a `stream` that is attached to a separate pipe instance.
    #
    # + topicName - The name of the topic which is used to subscribe
    # + 'limit - The maximum number of entries that are held in the pipe at once
    # + timeout - The maximum waiting period to receive events. Set the timeout to `-1` to wait without a time limit.
    # + typeParam - The `type` of data that is needed to be consumed. When not provided, the type is inferred
    # using the expected type from the function
    # + return - Returns `stream` if the user is successfully subscribed to the topic. Otherwise returns a
    # `pubsub:Error`
    public isolated function subscribe(string topicName, int 'limit = 5, decimal timeout = 30,
                                       typedesc<any> typeParam = <>)
        returns stream<typeParam, error?>|Error = @java:Method {
        'class: "io.xlibb.pubsub.PubSub"
    } external;

    private isolated function unsubscribe(string topicName, pipe:Pipe pipe) returns Error? {
        lock {
            pipe:Pipe[] pipes = self.topics.get(topicName);
            int i = 0;
            while i < pipes.length() {
                if pipe === pipes[i] {
                    _ = pipes.remove(i);
                    break;
                }
                i += 1;
            }
        }
    }

    # Creates a new topic in the PubSub.
    #
    # + topicName - The name of the topic which is used to publish/subscribe
    # + return - Returns `()` if the topic is successfully added to the PubSub. Otherwise returns a `pubsub:Error`
    public isolated function createTopic(string topicName) returns Error? {
        if self.isClosed {
            return error Error("Topics cannot be created in a closed PubSub");
        }
        lock {
            if self.topics.hasKey(topicName) {
                return error Error(string `Topic "${topicName}" already exists`);
            }
            self.topics[topicName] = [];
        }
    }

    # Closes the PubSub gracefully. Waits for the provided grace period before closing all the pipes in PubSub.
    #
    # + timeout - The grace period to wait until the pipes are closed
    # + return - Returns `()`, if the PubSub is successfully shutdown. Otherwise returns a `pubsub:Error`
    public isolated function gracefulShutdown(decimal timeout = 30) returns Error? {
        if timeout < 0d {
            return error Error("Shutdown timout cannot be a negative value");
        }
        if self.isClosed {
            return error Error("Closing of a closed PubSub is not allowed");
        }
        self.isClosed = true;
        lock {
            if self.topics != {} {
                runtime:sleep(timeout);
                check self.forceShutdown();
            }
        }
    }

    # Closes the PubSub instantly. All the pipes will be immediately closed.
    #
    # + return - Returns `()`, if the PubSub is successfully shutdown. Otherwise returns a `pubsub:Error`
    public isolated function forceShutdown() returns Error? {
        if self.isClosed && self.topics == {} {
            return error Error("Closing of a closed PubSub is not allowed");
        }
        self.isClosed = true;
        lock {
            pipe:Error? closingError = ();
            foreach pipe:Pipe[] pipes in self.topics {
                foreach pipe:Pipe pipe in pipes {
                    pipe:Error? immediateClose = pipe.immediateClose();
                    if immediateClose is pipe:Error {
                        closingError = immediateClose;
                    }
                }
            }
            self.topics.removeAll();
            if closingError != () {
                return error Error("Failed to shut down the pubsub", closingError);
            }
        }
    }
}
