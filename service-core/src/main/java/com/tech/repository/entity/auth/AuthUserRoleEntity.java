package com.tech.repository.entity.auth;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.tech.repository.entity.BaseEntity;
import com.tech.repository.entity.LogicEntity;
import lombok.Data;

/**
 * 用户-角色 关联表
 */
@Data
@TableName("auth_user_role")
public class AuthUserRoleEntity extends LogicEntity {
    /** 逻辑主键 */
    @TableId(value = "user_role_id", type = IdType.ASSIGN_ID)
    private Long userRoleId;
    /** 用户ID */
    private Long userId;
    /** 角色ID */
    private Long roleId;
}


