package io.xlibb.pubsub;

import io.ballerina.runtime.api.values.BError;

import java.util.concurrent.CompletableFuture;

import static io.xlibb.pubsub.utils.Utils.createError;

/**
 * Callback class for running Ballerina methods in PubSub Native code.
 */
public class MethodCallback {
    private final CompletableFuture<Object> future;

    protected MethodCallback(CompletableFuture<Object> future) {
        this.future = future;
    }

    public void notifySuccess(Object o) {
        if (o instanceof BError) {
            this.notifyFailure((BError) o);
        } else {
            this.future.complete(o);
        }
    }

    public void notifyFailure(BError bError) {
        BError pubsubError = createError("Failed to subscribe to topic", bError);
        this.future.complete(pubsubError);
    }
}
