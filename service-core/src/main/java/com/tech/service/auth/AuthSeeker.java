package com.tech.service.auth;

import com.tech.common.enums.auth.PermType;
import com.tech.domain.AuthDomain;
import com.tech.repository.entity.auth.AuthPermissionEntity;
import com.tech.repository.entity.auth.AuthRoleEntity;
import com.tech.repository.entity.auth.AuthRolePermissionEntity;
import com.tech.repository.entity.auth.AuthUserRoleEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections.CollectionUtils;
import org.springframework.stereotype.Service;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 权限查询类
 *
 * @author Jonas
 * @date 2025-08-09
 * @version 1.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthSeeker {

    private final AuthDomain authDomain;

    /**
     * 查询用户的权限编码集合
     */
    public Set<String> listUserPermission(Long userId, PermType permType) {
        Set<String> codes = new HashSet<>();
        if (userId == null) {
            return codes;
        }
        List<AuthUserRoleEntity> userRoles = authDomain.listAuthUserRole(userId);
        if (CollectionUtils.isEmpty(userRoles)) {
            return codes;
        }
        Set<Long> roleIds = userRoles.stream().map(AuthUserRoleEntity::getRoleId).collect(Collectors.toSet());
        List<AuthRoleEntity> roles = authDomain.listAuthRole(roleIds);
        if (CollectionUtils.isEmpty(roles)) {
            return codes;
        }
        roleIds = roles.stream().map(AuthRoleEntity::getRoleId).collect(Collectors.toSet());
        List<AuthRolePermissionEntity> rolePerms = authDomain.listAuthRolePermission(roleIds);
        if (CollectionUtils.isEmpty(rolePerms)) {
            return codes;
        }
        Set<Long> permIds = rolePerms.stream().map(AuthRolePermissionEntity::getPermId).collect(Collectors.toSet());
        if (permIds.isEmpty()) {
            return codes;
        }
        List<AuthPermissionEntity> perms = authDomain.listAuthPermission(permIds);
        if (permType == null) {
            return perms.stream().map(AuthPermissionEntity::getCode).collect(Collectors.toSet());
        }
        return perms.stream().filter(e -> permType.getCode().equals(e.getType()))
                .map(AuthPermissionEntity::getCode)
                .collect(Collectors.toSet());
    }
}
