import ballerina/http;
import xlibb/pubsub;

service / on new http:Listener(9090) {
    pubsub:PubSub pubsub;
    stream<string, error?> data;

    function init() returns error? {
        self.pubsub = new();
        self.data = check self.pubsub.subscribe("Topic", 50, 120);
    }

    resource function get subscribe() returns string|error {
        record {|string value;|}? next = check self.data.next();
        return (<record {|string value;|}>next).value;
    }

    resource function post publish(@http:Payload string payload) returns string|error {
        check self.pubsub.publish("Topic", payload, 120);
        return payload;
    }
}
