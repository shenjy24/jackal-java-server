package com.tech.common.annotation.auth;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 用户注解，通过该注解可在参数项获取用户信息
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-06
 */
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface User {
}
