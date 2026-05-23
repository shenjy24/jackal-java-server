package com.tech.repository.manager.auth;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.tech.repository.entity.auth.AuthRoleEntity;
import com.tech.repository.mapper.auth.AuthRoleMapper;
import org.apache.commons.collections.CollectionUtils;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * AuthRole DAO
 *
 * @author Jonas
 * @since 2026-05-23
 */
@Service
public class AuthRoleManager extends ServiceImpl<AuthRoleMapper, AuthRoleEntity> {
    public List<AuthRoleEntity> listAuthRole(Set<Long> roleIds) {
        if (CollectionUtils.isEmpty(roleIds)) {
            return Collections.emptyList();
        }
        LambdaQueryWrapper<AuthRoleEntity> queryWrapper = new LambdaQueryWrapper<>();
        queryWrapper.in(AuthRoleEntity::getRoleId, roleIds);
        return baseMapper.selectList(queryWrapper);
    }
}
