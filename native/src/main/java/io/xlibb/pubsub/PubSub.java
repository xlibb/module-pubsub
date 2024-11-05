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

package io.xlibb.pubsub;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BDecimal;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;

import java.util.concurrent.CompletableFuture;

import static io.xlibb.pubsub.utils.Utils.AUTO_CREATE_TOPICS;
import static io.xlibb.pubsub.utils.Utils.CONSUME_STREAM_METHOD;
import static io.xlibb.pubsub.utils.Utils.IS_CLOSED;
import static io.xlibb.pubsub.utils.Utils.PIPE_CLASS_NAME;
import static io.xlibb.pubsub.utils.Utils.PIPE_FIELD_NAME;
import static io.xlibb.pubsub.utils.Utils.TIMER_FIELD_NAME;
import static io.xlibb.pubsub.utils.Utils.TOPICS;
import static io.xlibb.pubsub.utils.Utils.createError;
import static io.xlibb.pubsub.utils.Utils.getResult;

/**
 * Provides a message communication model with publish/subscribe APIs.
 */
public class PubSub {
    private PubSub() {}

    public static Object subscribe(Environment environment, BObject pubsub, BString topicName, int limit,
                                   BDecimal timeout, BTypedesc typeParam) {
        if ((pubsub.get(IS_CLOSED)).equals(true)) {
            return createError("Users cannot subscribe to a closed PubSub");
        }
        BObject defaultPipe = pubsub.getObjectValue(PIPE_FIELD_NAME);
        Type pipeType = TypeUtils.getReferredType(defaultPipe.getType());
        BObject defaultTimer = pubsub.getObjectValue(TIMER_FIELD_NAME);
        Object[] fields = new Object[]{limit, defaultTimer};
        BObject pipe = ValueCreator.createObjectValue(pipeType.getPackage(), PIPE_CLASS_NAME, fields);
        try {
            addSubscriber(pubsub, topicName, pipe);
        } catch (BError bError) {
            return bError;
        }
        Object[] arguments = new Object[]{timeout, typeParam};
        CompletableFuture<Object> future = new CompletableFuture<>();
        MethodCallback callback = new MethodCallback(future);
        Thread.startVirtualThread(() -> {
            try {
                Object result = environment.getRuntime().startIsolatedWorker(pipe, CONSUME_STREAM_METHOD, null,
                        null,  null, arguments).get();
                callback.notifySuccess(result);
            } catch (BError bError) {
                callback.notifyFailure(bError);
            }
        });
        return getResult(future);
    }

    @SuppressWarnings("unchecked")
    public static void addSubscriber(BObject pubsub, BString topicName, BObject pipe) throws BError {
        BMap<BString, Object> topics = pubsub.getMapValue(TOPICS);
        boolean autoCreateTopics = pubsub.getBooleanValue(AUTO_CREATE_TOPICS);
        if (!topics.containsKey(topicName)) {
            if (!autoCreateTopics) {
                throw createError("Topic \"" + topicName + "\" does not exist");
            }
            Type pipeType = TypeUtils.getReferredType(pipe.getType());
            BArray pipes = ValueCreator.createArrayValue(TypeCreator.createArrayType(pipeType));
            pipes.append(pipe);
            topics.put(topicName, pipes);
        } else {
            BArray pipes = (BArray) topics.get(topicName);
            pipes.append(pipe);
            topics.put(topicName, pipes);
        }
    }
}
