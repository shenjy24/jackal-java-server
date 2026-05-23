package com.tech.config.interceptor;

import com.tech.common.annotation.auth.Anonymous;
import com.tech.common.annotation.auth.SemiAnonymous;
import com.tech.common.constant.Constants;
import com.tech.config.response.bean.BizException;
import com.tech.config.response.bean.SystemCode;
import com.tech.repository.entity.user.UserTokenEntity;
import com.tech.service.user.UserQueryService;
import com.tech.service.user.UserCommandService;
import com.tech.util.CookieUtil;
import com.tech.util.TimeUtil;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.lang.annotation.Annotation;

/**
 * 登录拦截器
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-01-02
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class LoginInterceptor implements HandlerInterceptor {

    private final UserQueryService userQueryService;
    private final UserCommandService userCommandService;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if (!(handler instanceof HandlerMethod handlerMethod)) {
            return true;
        }
        // 有Anonymous注解的方法可以匿名访问
        boolean anonymous = this.hasAnnotation(handlerMethod, Anonymous.class);
        if (anonymous) {
            return true;
        }
        String token = CookieUtil.getToken(request);
        boolean semiAnonymous = this.hasAnnotation(handlerMethod, SemiAnonymous.class);
        // 校验登陆态
        if (!semiAnonymous && StringUtils.isBlank(token)) {
            throw new BizException(SystemCode.NO_LOGIN);
        }
        // 匿名调用
        if (semiAnonymous && StringUtils.isBlank(token)) {
            return true;
        }

        UserTokenEntity userToken = userQueryService.getUserTokenByToken(token);
        if (userQueryService.isExpiredToken(userToken)) {
            if (semiAnonymous) {
                return true;
            }
            throw new BizException(SystemCode.NO_LOGIN);
        }

        // 检测是否需要延迟过期时间，临近指定时长则延长过期时间
        long currentTime = System.currentTimeMillis();
        long expireTime = userToken.getExpireTime().getTime();
        if (expireTime - currentTime < Constants.TOKEN_REFRESH_MS) {
            userToken.setExpireTime(TimeUtil.getTokenExpireTime());
            userCommandService.updateUserToken(userToken);
        }

        request.setAttribute(Constants.REQ_ATT_USER, userToken.getUserId());
        return true;
    }

    /**
     * 判断是否有指定注解
     *
     * @param method          处理器
     * @param annotationClass 注解类
     * @return 是否有指定注解
     */
    private boolean hasAnnotation(HandlerMethod method, Class<? extends Annotation> annotationClass) {
        return method.hasMethodAnnotation(annotationClass) ||
                method.getBeanType().isAnnotationPresent(annotationClass);
    }
}
