package com.tech.repository.entity.auth;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.tech.repository.entity.LogicEntity;
import lombok.Data;

/**
 * 权限表
 */
@Data
@TableName("auth_permission")
public class AuthPermissionEntity extends LogicEntity {
    /** 权限ID */
    @TableId(value = "perm_id", type = IdType.ASSIGN_ID)
    private Long permId;
    /** 权限编码（唯一） */
    private String code;
    /** 权限名称 */
    private String name;
    /** 权限类型 */
    private Integer type;
    /** 备注 */
    private String remark;
}


