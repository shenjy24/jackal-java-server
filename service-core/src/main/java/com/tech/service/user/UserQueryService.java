package com.tech.service.user;

import com.tech.repository.entity.user.UserEntity;
import com.tech.repository.entity.user.UserTokenEntity;
import com.tech.repository.manager.user.UserAccountManager;
import com.tech.repository.manager.user.UserManager;
import com.tech.repository.manager.user.UserTokenManager;
import com.tech.util.TimeUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

/**
 * 用户查询类
 *
 * @author shenjy
 * @version 1.0
 * @since 2025-02-12
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserQueryService {

    private final UserManager userManager;
    private final UserTokenManager userTokenManager;
    private final UserAccountManager userAccountManager;

    @Cacheable("userCache")
    public UserEntity getUser(Long userId) {
        if (userId == null) {
            return null;
        }
        return userManager.getById(userId);
    }

    public UserTokenEntity getUserTokenByToken(String token) {
        if (StringUtils.isBlank(token)) {
            return null;
        }
        return userTokenManager.getUserToken(token);
    }

    /**
     * 校验token是否有效
     *
     * @param userToken token实体
     * @return 是否有效
     */
    public boolean isExpiredToken(UserTokenEntity userToken) {
        if (userToken == null || userToken.getExpireTime() == null) {
            return true;
        }
        return TimeUtil.currentTimestamp().compareTo(userToken.getExpireTime()) > 0;
    }
}
