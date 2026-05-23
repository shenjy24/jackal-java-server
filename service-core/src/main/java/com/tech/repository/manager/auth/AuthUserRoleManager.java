package com.tech.repository.manager.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.tech.repository.entity.auth.AuthUserRoleEntity;
import com.tech.repository.mapper.auth.AuthUserRoleMapper;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;

/**
 * AuthUserRole DAO
 *
 * @author Jonas
 * @since 2026-05-23
 */
@Service
public class AuthUserRoleManager extends ServiceImpl<AuthUserRoleMapper, AuthUserRoleEntity> {

    public List<AuthUserRoleEntity> listAuthUserRole(Long userId) {
        if (userId == null) {
            return Collections.emptyList();
        }
        LambdaQueryWrapper<AuthUserRoleEntity> queryWrapper = new LambdaQueryWrapper<>();
        queryWrapper.eq(AuthUserRoleEntity::getUserId, userId);
        return baseMapper.selectList(queryWrapper);
    }
}
