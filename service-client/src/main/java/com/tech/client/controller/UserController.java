package com.tech.client.controller;

import com.tech.common.annotation.auth.Anonymous;
import com.tech.common.annotation.auth.UserId;
import com.tech.repository.entity.user.UserEntity;
import com.tech.repository.qo.user.LoginAccountQo;
import com.tech.repository.vo.user.UserVo;
import com.tech.service.user.UserAggregator;
import com.tech.service.user.UserSeeker;
import com.tech.service.user.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * UserController
 *
 * @author shenjy
 * @version 1.0
 * @date 2025-02-11
 */
@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/web/user")
public class UserController {

    private final UserSeeker userSeeker;
    private final UserService userService;
    private final UserAggregator userAggregator;

    /**
     * 账号密码登陆
     *
     * @param qo 账号密码参数
     * @return 用户信息
     */
    @Anonymous
    @PostMapping("/loginByAccount")
    public UserVo loginByAccount(@Valid @RequestBody LoginAccountQo qo) {
        UserEntity user = userService.loginByAccount(qo.getAccount(), qo.getPassword());
        return userAggregator.toUserVo(user);
    }

    /**
     * 获取用户信息
     *
     * @param userId 用户ID
     * @return 用户信息
     */
//    @Permission(Perms.USER_GET)
    @PostMapping("/getUser")
    public UserVo getUser(@UserId Long userId) {
        UserEntity user = userSeeker.getUser(userId);
        return userAggregator.toUserVo(user);
    }

}
