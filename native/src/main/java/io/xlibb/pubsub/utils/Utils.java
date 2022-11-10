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

package io.xlibb.pubsub.utils;

import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BString;

import static io.xlibb.pubsub.utils.ModuleUtils.getModule;

/**
 *  This class contains utility methods for the PubSub module.
 */
public class Utils {

    private Utils() {
    }

    // Internal type names
    public static final BString AUTO_CREATE_TOPICS = StringUtils.fromString("autoCreateTopics");
    public static final BString IS_CLOSED = StringUtils.fromString("closed");
    public static final BString PIPE_FIELD_NAME = StringUtils.fromString("pipe");
    public static final BString TIMER_FIELD_NAME = StringUtils.fromString("timer");
    public static final BString TOPICS = StringUtils.fromString("topics");
    public static final String CONSUME_STREAM_METHOD = "consumeStream";
    public static final String ERROR_TYPE = "Error";
    public static final String PIPE_CLASS_NAME = "Pipe";

    public static BError createError(String message) {
        return createError(message, null);
    }

    public static BError createError(String message, BError cause) {
        return ErrorCreator.createError(getModule(), ERROR_TYPE, StringUtils.fromString(message), cause, null);
    }
}
