package com.tech.repository.entity.auth;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.tech.repository.entity.LogicEntity;
import lombok.Data;

/**
 * 角色表
 */
@Data
@TableName("auth_role")
public class AuthRoleEntity extends LogicEntity {
    /** 角色ID */
    @TableId(value = "role_id", type = IdType.ASSIGN_ID)
    private Long roleId;
    /** 角色编码（唯一） */
    private String code;
    /** 角色名称 */
    private String name;
    /** 备注 */
    private String remark;
}


