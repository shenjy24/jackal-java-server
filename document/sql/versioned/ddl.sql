ALTER TABLE `auth_perm`
    ADD COLUMN `component` varchar(255) DEFAULT NULL COMMENT '前端组件路径' AFTER `path`;
