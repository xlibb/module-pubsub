# Ballerina Pub/Sub Library

[![Build](https://github.com/xlibb/module-pubsub/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/xlibb/module-pubsub/actions/workflows/build-timestamped-master.yml)
[![codecov](https://codecov.io/gh/xlibb/module-pubsub/branch/main/graph/badge.svg)](https://codecov.io/gh/xlibb/module-pubsub)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/xlibb/module-pubsub.svg)](https://github.com/xlibb/module-pubsub/commits/main)
[![Github issues](https://img.shields.io/github/issues/xlibb/module-pubsub/module/pubsub.svg?label=Open%20Issues)](https://github.com/xlibb/module-pubsub/labels/module%2Fpubsub)
[![GraalVM Check](https://github.com/xlibb/module-pubsub/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/xlibb/module-pubsub/actions/workflows/build-with-bal-test-graalvm.yml)

This library provides an event transmission model with publish/subscribe APIs.

**Note:** This library was originally created by [@Nuvindu](https://github.com/Nuvindu). Later it is moved to the xlibb organization.

## PubSub

PubSub is an events transmission model that consists of `publishers` sending data and `subscribers` receiving data. A logical channel called `topic` is used as the medium for publishers and subscribers to communicate. Users can subscribe to these topics. When data is published to one of the topics, it will broadcast that data to all the subscribers of the topic. In this approach, the senders and receivers are not directly connected.

#### Create a `pubsub:PubSub` instance

A `pubsub:PubSub` instance can be created as follows. It has a parameter to enable auto-creation of the non-existing topics when publishing/subscribing. The default value is set as `true`.

```ballerina
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new(autoCreateTopics = true);
}
```

### APIs associated with PubSub

- <b> publish </b>: Publishes data into a topic. Data will be broadcast to all the subscribers of that topic.
- <b> subscribe </b>: Subscribes to a topic in the PubSub. Subscriber will receive the data published on that topic.
- <b> createTopic </b>: Creates a new topic in the PubSub.
- <b> forceShutdown </b>: Closes the PubSub instantly. All the pipes will be immediately closed.
- <b> gracefulShutdown </b>: Closes the PubSub gracefully. Waits for the provided grace period before closing all the pipes in PubSub.

#### Create Topics

This method creates a new topic in the PubSub. There is a parameter called `autoCreateTopics` in the `pubsub` constructor which is set to `true` by default. That means it automatically creates necessary topics when the users are publishing/subscribing to non-existing topics.
If it is set to false, topics have to be manually created as below. The topic name must be provided.

```ballerina
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new(autoCreateTopics = false);
    check pubsub.createTopic("topic");
}
```

Creating existing topics or creating topics in a closed PubSub will return a `pubsub:Error`.

#### Publish Data to a Topic

Events can be published into a topic using this method. Once an event is published, it will be broadcast to all the current subscribers of that topic by producing that event to each `pipe` relevant to each subscriber.
The `publish` method requires a topic name, an event that needs to be published and a timeout as parameters. The `timeout` is a default parameter and it will be the maximum waiting period for an event to be hold in the buffer when a pipe attached to a subscriber is full.

```ballerina
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new();
    check pubsub.publish("topic", "event", timeout = 30);
}
```

When `autoCreateTopics` is not enabled, publishing events to non-existing topics or publishing events to a closed PubSub will return a `pubsub:Error`.

#### Subscribe to a Topic

A new subscriber will be created for a particular topic in the PubSub. The subscriber can receive the events published on that topic.

Each subscriber will receive a `stream` that is attached to a separate `pipe` instance. By invoking the `next` method, it returns the published event wrapped in a `record`. In the `subscribe` method, the name of the topic needs to be added as a parameter. Additionally, there are two default parameters in the method: `'limit` and `timeout`. Here the `'limit` means the limit of the pipe which generates the stream for the subscriber. And the `timeout` is the maximum waiting period to receive events from the stream of the pipe.

```ballerina
import ballerina/io;
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new();
    stream<string, error?> subscriberStream = check pubsub.subscribe("topic", 'limit = 5, timeout = 30);
    check pubsub.publish("topic", "event");

    record {|string value;|}? nextEvent = check subscriberStream.next();
    if nextEvent != () { string event = nextEvent.value; io:println(event);}
}
```

When `autoCreateTopics` is not enabled, subscribing to non-existing topics or subscribing to a closed Pubsub will return a `pubsub:Error`.

#### Shutdown

After a PubSub is shut down, users may no longer be able to use its APIs. And all the subscribers will be removed from the PubSub. And the closing of a closed PubSub will always return a `pubsub:Error`.

There are two approaches for closing a PubSub.

##### Force Shutdown

This method is to immediately shut down the PubSub. It closes all the pipes in the PubSub using the `immediateClose` method. After that, it will remove all the topics from the PubSub.

```ballerina
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new();
    check pubsub.forceShutdown();

    check pubsub.publish("topic", "event"); // This will produce an error
}
```

##### Graceful Shutdown

In the PubSub model, pipes are the intermediator for publishers and subscribers. Therefore these pipes can be in the middle of data transferring when the shutdown method is called. To prevent any unexpected behaviors, in the `gracefulShutdown` method, all the subscribers are granted a grace period to retrieve events from their streams. That period can be changed using the `timeout` parameter which is a default parameter for this method. During this period publishing events to the PubSub is not allowed. After the timeout elapses, it will close the PubSub using the `forceShutdown` method. The default timeout is 30 seconds.

```ballerina
import ballerina/io;
import ballerina/lang.runtime;
import xlibb/pubsub;

public function main() returns error? {
    pubsub:PubSub pubsub = new();
    stream<string, error?> subscriberStream = check pubsub.subscribe("topic");
    check pubsub.publish("topic", "event");

    worker A {
        pubsub:Error? close = pubsub.gracefulShutdown(timeout = 10);
        pubsub:Error? publish = pubsub.publish("topic", "event_2"); // This will produce an error
        io:println(publish);
    }

    @strand {
        thread: "any"
    }
    worker B {
        runtime:sleep(5);
        record {|string value;|}|error? nextEvent = subscriberStream.next();
        if nextEvent !is error? { string event = nextEvent.value; io:println(event); }
    }
}
```

## Build from the source

### Set up the prerequisites

1.  Download and install Java SE Development Kit (JDK) version 21 (from one of the following locations).

    - [Oracle](https://www.oracle.com/java/technologies/javase-jdk21-downloads.html)

    - [OpenJDK](https://adoptopenjdk.net/)

      > **Note:** Set the JAVA_HOME environment variable to the path name of the directory into which you installed JDK.

2.  Export your Github Personal access token with the read package permissions as follows.

              export packageUser=<Username>
              export packagePAT=<Personal access token>

### Build the source

Execute the commands below to build from the source.

1. To build the library:

   ```
   ./gradlew clean build
   ```

2. To run the integration tests:
   ```
   ./gradlew clean test
   ```
3. To build the module without the tests:
   ```
   ./gradlew clean build -x test
   ```
4. To debug module implementation:
   ```
   ./gradlew clean build -Pdebug=<port>
   ./gradlew clean test -Pdebug=<port>
   ```
5. To debug the module with Ballerina language:
   ```
   ./gradlew clean build -PbalJavaDebug=<port>
   ./gradlew clean test -PbalJavaDebug=<port>
   ```
6. Publish ZIP artifact to the local `.m2` repository:
   ```
   ./gradlew clean build publishToMavenLocal
   ```
7. Publish the generated artifacts to the local Ballerina central repository:
   ```
   ./gradlew clean build -PpublishToLocalCentral=true
   ```
8. Publish the generated artifacts to the Ballerina central repository:
   ```
   ./gradlew clean build -PpublishToCentral=true
   ```
