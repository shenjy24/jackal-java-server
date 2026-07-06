# MySQL 宿主机部署文档

本文档说明如何使用 `install_mysql.sh` 在 Ubuntu 22.04 宿主机上离线安装 MySQL 8.4.10。

## 目录说明

```text
document/deploy/mysql/host/
├── install_mysql.sh    # MySQL 离线安装脚本
├── my.cnf              # 宿主机 MySQL 配置
├── libaio1_0.3.112-13build1_amd64.deb
├── numactl_2.0.14-3ubuntu2_amd64.deb
└── mysql-8.4.10-linux-glibc2.17-x86_64.tar.xz
```

当前仓库只提交了脚本和 `my.cnf`。实际部署前，需要将上面的两个 `.deb` 依赖包和 MySQL 安装包放到 `install_mysql.sh` 同目录。

## 部署前检查

脚本主要按 Ubuntu 22.04 验证，执行前请确认：

- 使用 `root` 用户或 `sudo` 权限执行。
- 3306 端口未被其他 MySQL、MariaDB 或 Docker 容器占用。
- `/usr/local/mysql` 不存在，或已经确认可以重装。
- 目标机器使用 `systemd` 管理服务。
- 安装包文件名与脚本中的配置一致。

检查端口占用：

```bash
ss -ltn | grep ':3306'
```

## 首次安装

进入脚本目录：

```bash
cd document/deploy/mysql/host
```

建议显式设置 root 密码：

```bash
sudo ROOT_PWD='YourStrongPass' ./install_mysql.sh
```

如果未设置 `ROOT_PWD`，脚本会使用默认密码 `123456`，仅建议本地临时环境使用。

安装成功后使 PATH 生效：

```bash
source /etc/profile
```

## 配置变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ROOT_PWD` | `123456` | `root@localhost` 密码 |
| `FORCE_REINSTALL` | `false` | 是否允许重装已有 `/usr/local/mysql` |
| `ALLOW_REMOTE_ROOT` | `false` | 是否创建并授权 `root@'%'` |
| `STARTUP_TIMEOUT` | `60` | 等待 MySQL 临时服务启动的秒数 |

示例：

```bash
sudo ROOT_PWD='YourStrongPass' STARTUP_TIMEOUT=90 ./install_mysql.sh
```

## 重装说明

脚本默认保护已有数据。如果 `/usr/local/mysql` 已存在，脚本会停止并提示，不会删除目录。

确认需要重装时：

```bash
sudo FORCE_REINSTALL=true ROOT_PWD='YourStrongPass' ./install_mysql.sh
```

重装时脚本会先停止已有 `mysqld` 服务，然后将旧目录移动为：

```text
/usr/local/mysql.bak.yyyyMMddHHmmss
```

确认新实例运行正常并完成数据迁移后，再手动清理旧备份目录。

## 远程 root

默认只配置 `root@localhost`。如确实需要远程 root：

```bash
sudo ALLOW_REMOTE_ROOT=true ROOT_PWD='YourStrongPass' ./install_mysql.sh
```

开启远程 root 时，脚本会拒绝使用默认密码 `123456`。

生产环境不建议开放 `root@'%'`，建议创建业务账号并限制来源 IP：

```sql
CREATE USER 'app_user'@'10.%' IDENTIFIED BY 'StrongAppPass';
GRANT SELECT, INSERT, UPDATE, DELETE ON your_database.* TO 'app_user'@'10.%';
FLUSH PRIVILEGES;
```

## 安装结果

脚本会写入或更新以下系统路径：

```text
/usr/local/mysql
/usr/local/mysql/data
/etc/my.cnf
/etc/systemd/system/mysqld.service
/etc/profile
```

覆盖 `/etc/my.cnf` 或 `mysqld.service` 前，脚本会自动生成 `.bak.yyyyMMddHHmmss` 备份文件。

## 常用命令

```bash
# 查看服务状态
systemctl status mysqld

# 启动
systemctl start mysqld

# 停止
systemctl stop mysqld

# 重启
systemctl restart mysqld

# 查看错误日志
tail -f /usr/local/mysql/data/error.log

# 本地登录
mysql -uroot -p
```

## 验证安装

查看 MySQL 版本：

```bash
mysql --version
```

登录后查看用户：

```sql
SELECT user, host FROM mysql.user;
```

查看端口监听：

```bash
ss -ltn | grep ':3306'
```

## 注意事项

- 执行前请先备份已有数据库数据。
- 不要在生产环境使用默认 root 密码。
- 不要把真实密码、Token 或数据库备份提交到代码仓库。
- `my.cnf` 中 `innodb_flush_log_at_trx_commit = 2` 偏性能优先，极端宕机场景可能丢失最近约 1 秒事务，生产环境需按数据安全要求评估。
- 脚本不负责初始化业务库和业务表结构，业务 SQL 请单独执行。
