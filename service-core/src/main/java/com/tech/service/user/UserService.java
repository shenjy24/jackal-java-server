package com.tech.service.user;

import com.tech.common.enums.ErrorCode;
import com.tech.config.response.bean.BizException;
import com.tech.domain.UserDomain;
import com.tech.repository.entity.user.UserAccountEntity;
import com.tech.repository.entity.user.UserEntity;
import com.tech.repository.entity.user.UserTokenEntity;
import com.tech.util.CookieUtil;
import com.tech.util.IdUtil;
import com.tech.util.MD5Util;
import com.tech.util.TimeUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.sql.Timestamp;

/**
 * 用户服务类
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-02-13
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserDomain userDomain;

    /**
     * 账号密码登陆
     *
     * @param account  账号
     * @param password 密码
     * @return 用户ID
     */
    public UserEntity loginByAccount(String account, String password) {
        UserAccountEntity userAccount = userDomain.getUserAccount(account);
        if (userAccount == null) {
            throw new BizException(ErrorCode.USER_ERROR4);
        }
        if (!MD5Util.verifySaltMd5(password, userAccount.getPassword())) {
            throw new BizException(ErrorCode.USER_ERROR4);
        }
        UserEntity user = userDomain.getUser(userAccount.getUserId());
        if (user == null) {
            throw new BizException(ErrorCode.USER_ERROR4);
        }
        // 设置token
        UserTokenEntity userToken = saveOrUpdateUserToken(userAccount.getUserId());
        // 设置Cookie
        CookieUtil.setCookie(userToken.getToken());

        return user;
    }

    private UserTokenEntity saveOrUpdateUserToken(Long userId) {
        if (userId == null) {
            throw new BizException(ErrorCode.PARAM_ERROR);
        }
        UserTokenEntity userToken = userDomain.getUserToken(userId);
        String token = IdUtil.uuid();
        Timestamp expireTime = TimeUtil.getTokenExpireTime();
        if (null == userToken) {
            userToken = new UserTokenEntity().setUserId(userId).setToken(token).setExpireTime(expireTime);
            userDomain.saveUserToken(userToken);
        } else {
            userToken.setToken(token).setExpireTime(expireTime);
            userDomain.updateUserToken(userToken);
        }
        return userToken;
    }

    public void updateUserToken(UserTokenEntity userToken) {
        if (userToken == null || userToken.getTokenId() == null) {
            return;
        }
        userDomain.updateUserToken(userToken);
    }
}
