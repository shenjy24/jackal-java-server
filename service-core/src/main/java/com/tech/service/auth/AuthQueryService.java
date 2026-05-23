package com.tech.service.auth;

import com.tech.common.enums.auth.PermType;
import com.tech.repository.entity.auth.AuthPermissionEntity;
import com.tech.repository.entity.auth.AuthRoleEntity;
import com.tech.repository.entity.auth.AuthRolePermissionEntity;
import com.tech.repository.entity.auth.AuthUserRoleEntity;
import com.tech.repository.dao.auth.AuthPermissionDao;
import com.tech.repository.dao.auth.AuthRoleDao;
import com.tech.repository.dao.auth.AuthRolePermissionDao;
import com.tech.repository.dao.auth.AuthUserRoleDao;
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
 * @version 1.0
 * @since 2025-08-09
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthQueryService {

    private final AuthRoleDao authRoleDao;
    private final AuthUserRoleDao authUserRoleDao;
    private final AuthPermissionDao authPermissionDao;
    private final AuthRolePermissionDao authRolePermissionDao;

    /**
     * 查询用户的权限编码集合
     */
    public Set<String> listUserPermission(Long userId, PermType permType) {
        Set<String> codes = new HashSet<>();
        if (userId == null) {
            return codes;
        }
        List<AuthUserRoleEntity> userRoles = authUserRoleDao.listAuthUserRole(userId);
        if (CollectionUtils.isEmpty(userRoles)) {
            return codes;
        }
        Set<Long> roleIds = userRoles.stream().map(AuthUserRoleEntity::getRoleId).collect(Collectors.toSet());
        List<AuthRoleEntity> roles = authRoleDao.listAuthRole(roleIds);
        if (CollectionUtils.isEmpty(roles)) {
            return codes;
        }
        roleIds = roles.stream().map(AuthRoleEntity::getRoleId).collect(Collectors.toSet());
        List<AuthRolePermissionEntity> rolePerms = authRolePermissionDao.listAuthRolePermission(roleIds);
        if (CollectionUtils.isEmpty(rolePerms)) {
            return codes;
        }
        Set<Long> permIds = rolePerms.stream().map(AuthRolePermissionEntity::getPermId).collect(Collectors.toSet());
        if (permIds.isEmpty()) {
            return codes;
        }
        List<AuthPermissionEntity> perms = authPermissionDao.listAuthPermission(permIds);
        if (permType == null) {
            return perms.stream().map(AuthPermissionEntity::getCode).collect(Collectors.toSet());
        }
        return perms.stream().filter(e -> permType.getCode().equals(e.getType()))
                .map(AuthPermissionEntity::getCode)
                .collect(Collectors.toSet());
    }
}
