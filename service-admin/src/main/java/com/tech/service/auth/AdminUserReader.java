package com.tech.service.auth;

import com.tech.repository.entity.auth.AdminUserEntity;
import com.tech.repository.entity.auth.AdminUserTokenEntity;
import com.tech.repository.dao.auth.AdminUserDao;
import com.tech.repository.dao.auth.AdminUserTokenDao;
import com.tech.util.TimeUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminUserReader {

    private final AdminUserDao adminUserDao;
    private final AdminUserTokenDao adminUserTokenDao;

    public AdminUserEntity getById(Long adminUserId) {
        if (adminUserId == null) {
            return null;
        }
        return adminUserDao.getById(adminUserId);
    }

    public AdminUserTokenEntity getTokenByToken(String token) {
        if (StringUtils.isBlank(token)) {
            return null;
        }
        return adminUserTokenDao.getByToken(token);
    }

    public boolean isExpiredToken(AdminUserTokenEntity token) {
        if (token == null || token.getExpireTime() == null) {
            return true;
        }
        return TimeUtil.currentTimestamp().compareTo(token.getExpireTime()) > 0;
    }
}
