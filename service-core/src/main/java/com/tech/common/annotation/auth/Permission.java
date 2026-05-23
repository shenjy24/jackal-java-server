package com.tech.common.annotation.auth;

import java.lang.annotation.*;

/**
 * 权限注解：在方法或类上标注所需权限编码
 */
@Documented
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface Permission {
    /**
     * 需要的权限编码，通常为模块:操作 例如 user:read
     */
    String[] value();

    /**
     * 是否需要全部匹配。true 表示需要具备全部权限；false 表示具备任意一个权限即可。
     */
    boolean requireAll() default true;
}


