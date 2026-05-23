package com.tech.domain;

import com.baomidou.mybatisplus.extension.conditions.query.LambdaQueryChainWrapper;
import com.tech.repository.entity.user.UserAccountEntity;
import com.tech.repository.entity.user.UserEntity;
import com.tech.repository.entity.user.UserTokenEntity;
import com.tech.repository.mapper.user.UserAccountMapper;
import com.tech.repository.mapper.user.UserMapper;
import com.tech.repository.mapper.user.UserTokenMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Component;

/**
 * UserDomain
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-02-12
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class UserDomain {
    private final UserMapper userMapper;
    private final UserTokenMapper userTokenMapper;
    private final UserAccountMapper userAccountMapper;

    public UserEntity getUser(Long userId) {
        if (userId == null) {
            return null;
        }
        return userMapper.selectById(userId);
    }

    public UserTokenEntity getUserToken(Long userId) {
        if (userId == null) {
            return null;
        }
        return new LambdaQueryChainWrapper<>(userTokenMapper)
                .eq(UserTokenEntity::getUserId, userId)
                .one();
    }

    public UserTokenEntity getUserToken(String token) {
        if (StringUtils.isBlank(token)) {
            return null;
        }
        return new LambdaQueryChainWrapper<>(userTokenMapper)
                .eq(UserTokenEntity::getToken, token)
                .one();
    }

    public void saveUserToken(UserTokenEntity userToken) {
        if (userToken == null) {
            return;
        }
        userTokenMapper.insert(userToken);
    }

    public void updateUserToken(UserTokenEntity userToken) {
        if (userToken == null || userToken.getTokenId() == null) {
            return;
        }
        userTokenMapper.updateById(userToken);
    }

    public UserAccountEntity getUserAccount(String account) {
        if (StringUtils.isBlank(account)) {
            return null;
        }
        return new LambdaQueryChainWrapper<>(userAccountMapper)
                .eq(UserAccountEntity::getAccount, account)
                .one();
    }
}
