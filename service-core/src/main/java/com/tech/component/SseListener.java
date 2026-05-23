package com.tech.component;

import okhttp3.Response;

/**
 * SseListener
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-01-06
 */
public interface SseListener {
    void onEvent(String event, String data);

    void onError(Exception e);

    void onFail(Response response);
}
