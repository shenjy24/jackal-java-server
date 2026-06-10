package com.tech.config;

import com.tech.config.interceptor.AdminAuthInterceptor;
import com.tech.config.interceptor.AdminLoginInterceptor;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 管理后台 WEB 配置：注册登录与权限拦截器。
 * 通用的 CORS、消息转换、参数解析由 service-core 的 WebConfig 提供。
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-01-06
 */
@Configuration
@RequiredArgsConstructor
public class AdminWebConfig implements WebMvcConfigurer {

    private final AdminLoginInterceptor adminLoginInterceptor;
    private final AdminAuthInterceptor adminAuthInterceptor;

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(adminLoginInterceptor).addPathPatterns("/admin/**");
        registry.addInterceptor(adminAuthInterceptor).addPathPatterns("/admin/**");
    }
}
