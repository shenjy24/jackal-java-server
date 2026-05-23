package com.tech.repository.entity.auth;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.tech.repository.entity.LogicEntity;
import lombok.Data;

@Data
@TableName("admin_user")
public class AdminUserEntity extends LogicEntity {
    @TableId(value = "admin_user_id", type = IdType.ASSIGN_ID)
    private Long adminUserId;
    private String nickname;
    private String avatar;
    private String account;
    private String password;
}
