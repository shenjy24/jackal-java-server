package com.tech.config.interceptor;

import com.tech.common.annotation.auth.Permission;
import com.tech.common.constant.Constants;
import com.tech.common.enums.auth.PermType;
import com.tech.config.response.bean.BizException;
import com.tech.config.response.bean.SystemCode;
import com.tech.service.auth.AuthQueryService;
import com.tech.service.user.UserQueryService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.Arrays;
import java.util.Set;

/**
 * 权限拦截器
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-02
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AuthInterceptor implements HandlerInterceptor {

    private final UserQueryService userQueryService;
    private final AuthQueryService authQueryService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if (!(handler instanceof HandlerMethod handlerMethod)) {
            return true;
        }
        Permission permission = handlerMethod.getMethodAnnotation(Permission.class);
        if (permission == null) {
            return true;
        }

        // 没登录则不需要校验
        if (request.getAttribute(Constants.REQ_ATT_USER) == null) {
            return true;
        }
        Long userId = (Long) request.getAttribute(Constants.REQ_ATT_USER);

        // 权限校验：方法或类上标注了 @Permission 则校验用户是否具备
        Set<String> userPerms = authQueryService.listUserPermission(userId, PermType.API);
        String[] needPerms = permission.value();
        boolean requireAll = permission.requireAll();
        boolean passed;
        if (requireAll) {
            passed = Arrays.stream(needPerms).allMatch(userPerms::contains);
        } else {
            passed = Arrays.stream(needPerms).anyMatch(userPerms::contains);
        }
        if (!passed) {
            throw new BizException(SystemCode.NO_PERM);
        }

        return true;
    }
}
