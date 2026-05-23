package com.tech.domain;

import com.baomidou.mybatisplus.extension.conditions.query.LambdaQueryChainWrapper;
import com.tech.repository.entity.auth.AuthPermissionEntity;
import com.tech.repository.entity.auth.AuthRoleEntity;
import com.tech.repository.entity.auth.AuthRolePermissionEntity;
import com.tech.repository.entity.auth.AuthUserRoleEntity;
import com.tech.repository.mapper.auth.AuthPermissionMapper;
import com.tech.repository.mapper.auth.AuthRoleMapper;
import com.tech.repository.mapper.auth.AuthRolePermissionMapper;
import com.tech.repository.mapper.auth.AuthUserRoleMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections.CollectionUtils;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * AuthDomain
 *
 * @author Jonas
 * @date 2025-08-09
 * @version 1.0
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AuthDomain {
    private final AuthRoleMapper authRoleMapper;
    private final AuthUserRoleMapper authUserRoleMapper;
    private final AuthRolePermissionMapper authRolePermissionMapper;
    private final AuthPermissionMapper authPermissionMapper;

    public List<AuthUserRoleEntity> listAuthUserRole(Long userId) {
        if (userId == null) {
            return Collections.emptyList();
        }
        return new LambdaQueryChainWrapper<>(authUserRoleMapper)
                .eq(AuthUserRoleEntity::getUserId, userId)
                .list();
    }

    public List<AuthRolePermissionEntity> listAuthRolePermission(Set<Long> roleIds) {
        if (CollectionUtils.isEmpty(roleIds)) {
            return Collections.emptyList();
        }
        return new LambdaQueryChainWrapper<>(authRolePermissionMapper)
                .in(AuthRolePermissionEntity::getRoleId, roleIds)
                .list();
    }

    public List<AuthPermissionEntity> listAuthPermission(Set<Long> permIds) {
        if (CollectionUtils.isEmpty(permIds)) {
            return Collections.emptyList();
        }
        return new LambdaQueryChainWrapper<>(authPermissionMapper)
                .in(AuthPermissionEntity::getPermId, permIds)
                .list();
    }

    public List<AuthRoleEntity> listAuthRole(Set<Long> roleIds) {
        if (CollectionUtils.isEmpty(roleIds)) {
            return Collections.emptyList();
        }
        return new LambdaQueryChainWrapper<>(authRoleMapper)
                .in(AuthRoleEntity::getRoleId, roleIds)
                .list();

    }
}
