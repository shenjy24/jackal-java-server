# 离线软件包

在执行 `../install-software.sh` 之前，请将离线安装所需的软件包放到当前目录。

默认文件名如下：

- `docker-29.5.3.tgz`
- `docker-compose-linux-x86_64`

如果目标服务器为 Ubuntu 22.04，且未安装 `iptables`，请将 `iptables` 及其依赖的 `.deb` 文件直接放入当前 `pkgs/` 目录：

```text
pkgs/
├── iptables_1.8.7-1ubuntu5.2_amd64.deb
└── （iptables 依赖的其他 .deb 文件）
```

脚本会在未找到 `iptables` 时一次性执行 `dpkg -i pkgs/*.deb`。默认主包文件名为 `iptables_1.8.7-1ubuntu5.2_amd64.deb`，可通过 `IPTABLES_DEB_DIR`、`IPTABLES_DEB` 覆盖。

如果实际文件名不同，可以通过 `DOCKER_ARCHIVE`、`DOCKER_COMPOSE_BINARY` 环境变量覆盖。
