package com.tech.config;

import com.tech.config.interceptor.UserLoginInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * C 端 WEB 配置：注册用户登录拦截器。
 * 通用的 CORS、消息转换、参数解析由 service-core 的 WebConfig 提供。
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-01-06
 */
@Configuration
@RequiredArgsConstructor
public class ClientWebConfig implements WebMvcConfigurer {

    private final UserLoginInterceptor userLoginInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(userLoginInterceptor).addPathPatterns("/web/**");
    }
}
