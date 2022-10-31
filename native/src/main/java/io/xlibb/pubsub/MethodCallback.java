package io.xlibb.pubsub;

import io.ballerina.runtime.api.Future;
import io.ballerina.runtime.api.async.Callback;
import io.ballerina.runtime.api.values.BError;

/**
 * Callback class for running Ballerina methods in PubSub Native code.
 */
public class MethodCallback implements Callback {
    private final Future future;

    protected MethodCallback(Future future) {
        this.future = future;
    }

    @Override
    public void notifySuccess(Object o) {
        this.future.complete(o);
    }

    @Override
    public void notifyFailure(BError bError) {
        this.future.complete(bError);
    }
}
