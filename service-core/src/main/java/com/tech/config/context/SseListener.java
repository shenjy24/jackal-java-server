package com.tech.config.context;

import okhttp3.Response;

public interface SseListener {
    void onEvent(String event, String data);

    void onError(Exception e);

    void onFail(Response response);
}
