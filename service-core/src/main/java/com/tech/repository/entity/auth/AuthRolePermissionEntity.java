package com.tech.repository.entity.auth;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.tech.repository.entity.BaseEntity;
import com.tech.repository.entity.LogicEntity;
import lombok.Data;

/**
 * 角色-权限 关联表
 */
@Data
@TableName("auth_role_permission")
public class AuthRolePermissionEntity extends LogicEntity {
    /** 逻辑主键 */
    @TableId(value = "role_perm_id", type = IdType.ASSIGN_ID)
    private Long rolePermId;
    /** 角色ID */
    private Long roleId;
    /** 权限ID */
    private Long permId;
}


