package com.tech.util;

import com.tech.common.constant.Constants;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

public class CookieUtil {

    /**
     * 封装设置cookie方法
     *
     * @param response    响应对象
     * @param cookieName  Cookie 名
     * @param cookieValue Cookie 值
     * @param maxAge      存活最大时间
     */
    public static void setCookie(HttpServletResponse response, String cookieName, String cookieValue, int maxAge) {
        Cookie cookie = new Cookie(cookieName, cookieValue);
        cookie.setPath("/");
        cookie.setMaxAge(maxAge);
        cookie.setHttpOnly(true);
        response.addCookie(cookie);
    }

    /**
     * 设置Cookie
     *
     * @param token 登录token
     */
    public static void setCookie(String token) {
        setCookie(ServletUtil.getResponse(), Constants.COOKIE_KEY_TOKEN, token, Constants.TOKEN_EXPIRED_MS / 1000);
    }

    /**
     * 删除Cookie
     *
     * @param cookieName cookie名
     */
    public static void removeCookie(String cookieName) {
        removeCookie(ServletUtil.getResponse(), cookieName);
    }

    public static void removeCookie(HttpServletResponse response, String cookieName) {
        Cookie cookie = new Cookie(cookieName, null);
        cookie.setPath("/");//总域名底下都能找到
        cookie.setMaxAge(0);
        cookie.setHttpOnly(true);
        response.addCookie(cookie);
    }

    public static String getToken(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null || cookies.length == 0) {
            return "";
        }
        for (Cookie cookie : request.getCookies()) {
            if (cookie.getName().equals(Constants.COOKIE_KEY_TOKEN)) {
                return cookie.getValue();
            }
        }
        return "";
    }
}
