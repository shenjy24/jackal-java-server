# IoTDB 宿主机部署文档

本文档说明如何使用 `install_iotdb.sh` 在 Ubuntu 22.04 宿主机上离线安装 IoTDB 2.0.6 单机版。

## 目录说明

```text
document/deploy/iotdb/host/
├── install_iotdb.sh                         # IoTDB 离线安装脚本
├── IoTDB宿主机部署文档.md
├── apache-iotdb-2.0.6-all-bin.zip           # 需手动下载，不提交 Git
└── jdk-21*.tar.gz                           # 可选，目标机没有 JDK21 时使用，不提交 Git
```

当前仓库只提交脚本和文档。实际部署前，请将所需安装包放到 `install_iotdb.sh` 同目录。

## 依赖清单

必需下载：

```text
apache-iotdb-2.0.6-all-bin.zip
```

JDK21 二选一：

- 目标机已安装 JDK21，且 `java -version` 可用。
- 将 `jdk-21*.tar.gz` 放到脚本目录，脚本会解压到 `/usr/local` 并用于 IoTDB systemd 服务。

目标机还需要具备以下基础命令：

```text
awk cat chmod chown cp date dirname find grep groupadd head id mkdir mktemp mv readlink rm sed sleep sort ss systemctl tar tr unzip useradd
```

如最小化系统缺少命令，请提前安装：

```bash
sudo apt install -y unzip tar coreutils iproute2
```

## 部署前检查

执行前请确认：

- 使用 `root` 用户或 `sudo` 权限执行。
- 目标机器使用 `systemd` 管理服务。
- `/usr/local/iotdb` 不存在，或已经确认可以重装。
- 以下端口未被占用：`6667`、`10710`、`10720`、`10730`、`10740`、`10750`、`10760`。

检查端口占用：

```bash
ss -ltn | grep -E ':(6667|10710|10720|10730|10740|10750|10760)\b'
```

## 首次安装

进入脚本目录：

```bash
cd document/deploy/iotdb/host
```

执行安装：

```bash
sudo ./install_iotdb.sh
```

安装成功后使环境变量生效：

```bash
source /etc/profile
```

## 配置变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `DN_RPC_ADDRESS` | `127.0.0.1` | DataNode RPC 对外地址 |
| `DN_RPC_PORT` | `6667` | DataNode RPC 端口 |
| `CONFIGNODE_MEMORY_SIZE` | `256M` | ConfigNode 内存配置 |
| `DATANODE_MEMORY_SIZE` | `512M` | DataNode 内存配置 |
| `FORCE_REINSTALL` | `false` | 是否允许重装已有 `/usr/local/iotdb` |
| `STARTUP_TIMEOUT` | `90` | 等待服务端口监听的秒数 |

如果应用需要从其他机器访问 IoTDB，请将 `DN_RPC_ADDRESS` 设置为客户端可访问的服务器 IP 或主机名：

```bash
sudo DN_RPC_ADDRESS='192.168.1.10' ./install_iotdb.sh
```

调整内存：

```bash
sudo CONFIGNODE_MEMORY_SIZE='512M' DATANODE_MEMORY_SIZE='1G' ./install_iotdb.sh
```

## 重装说明

脚本默认保护已有数据。如果 `/usr/local/iotdb` 已存在，脚本会停止并提示，不会删除目录。

确认需要重装时：

```bash
sudo FORCE_REINSTALL=true ./install_iotdb.sh
```

重装时脚本会先停止已有服务，然后将旧目录移动为：

```text
/usr/local/iotdb.bak.yyyyMMddHHmmss
```

确认新实例运行正常并完成数据迁移后，再手动清理旧备份目录。

## 安装结果

脚本会写入或更新以下系统路径：

```text
/usr/local/iotdb
/etc/systemd/system/iotdb-confignode.service
/etc/systemd/system/iotdb-datanode.service
/etc/profile
```

覆盖 systemd service 前，脚本会自动生成 `.bak.yyyyMMddHHmmss` 备份文件。

脚本会创建两个 systemd 服务：

```text
iotdb-confignode
iotdb-datanode
```

## 初始化数据库

应用配置中使用的 IoTDB 数据库需要提前创建。进入 IoTDB CLI：

```bash
/usr/local/iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root -sql_dialect table
```

按实际 profile 创建数据库，例如：

```sql
CREATE DATABASE rd3;
CREATE DATABASE rd3_dev;
SHOW DATABASES;
```

应用配置中的 JDBC URL 和 `iotdb.session.database` 需要与这里创建的数据库保持一致。

## 常用命令

```bash
# 查看服务状态
systemctl status iotdb-confignode iotdb-datanode

# 启动
systemctl start iotdb-confignode iotdb-datanode

# 停止
systemctl stop iotdb-datanode iotdb-confignode

# 重启
systemctl restart iotdb-confignode iotdb-datanode

# 查看端口
ss -ltn | grep ':6667'

# 查看日志
tail -f /usr/local/iotdb/logs/log_datanode_all.log

# 进入 IoTDB 命令行
/usr/local/iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root -sql_dialect table
```

## 验证安装

查看服务：

```bash
systemctl status iotdb-confignode iotdb-datanode
```

查看 RPC 端口：

```bash
ss -ltn | grep ':6667'
```

使用 CLI 连接：

```bash
/usr/local/iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root -sql_dialect table
```

登录后执行：

```sql
SHOW VERSION;
SHOW DATABASES;
```

## 注意事项

- 执行前请先备份已有 IoTDB 数据。
- 依赖包、JDK 包和数据库备份不要提交到 Git。
- 默认账号密码为 IoTDB 内置的 `root/root`，生产环境应修改默认密码并同步更新应用配置。
- 默认 `DN_RPC_ADDRESS=127.0.0.1` 只适合本机访问；远程访问必须设置为客户端可访问地址，并确认防火墙策略。
- 脚本只负责安装 IoTDB 和启动服务，不负责初始化业务数据库和业务数据。
- 如果需要备份恢复能力，可继续使用 Docker 部署目录下的备份思路，但宿主机部署需要单独适配备份脚本。
