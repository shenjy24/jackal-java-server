# IoTDB 部署文档

本文档说明如何使用 `docker-compose-iotdb.yml` 部署 IoTDB，以及如何使用 `iotdb-backup.sh` 手动备份和配置定时备份。

## 目录说明

```text
doc/deploy/iotdb/
├── docker-compose-iotdb.yml    # IoTDB Docker Compose 配置
├── iotdb-backup.sh             # IoTDB 在线导出备份脚本
├── logs/                       # IoTDB 日志挂载目录
└── backup/                     # 备份文件输出目录
```

IoTDB 数据使用固定 Docker volume `iotdb-data` 持久化，容器删除后数据不会随容器一起删除。

## 部署 IoTDB

进入部署目录：

```bash
cd doc/deploy/iotdb
```

如需覆盖默认端口或绑定地址，可直接修改当前目录下的 `app.env` 文件：

```env
IOTDB_BIND_IP=0.0.0.0
IOTDB_RPC_PORT=6667
DN_RPC_ADDRESS=0.0.0.0
```

变量说明：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `IOTDB_BIND_IP` | `0.0.0.0` | 宿主机监听地址，外部访问需要保持为 `0.0.0.0` 或指定可访问 IP |
| `IOTDB_RPC_PORT` | `6667` | 宿主机映射端口，应用通过该端口访问 IoTDB |
| `DN_RPC_ADDRESS` | `0.0.0.0` | DataNode RPC 容器内监听地址，bridge 网络下不建议写宿主机 IP |

外部客户端连接时使用宿主机 IP 和映射端口，例如：

```bash
/iotdb/sbin/start-cli.sh -h 192.168.1.10 -p 6667 -u root -pw root
```

启动 IoTDB：

```bash
bash up.sh
```

查看容器状态：

```bash
docker ps --filter name=iotdb
docker compose -f docker-compose-iotdb.yml ps
```

查看日志：

```bash
docker logs -f iotdb
```

停止服务：

```bash
docker compose -f docker-compose-iotdb.yml down
```

如需连同数据卷一起删除，执行前请确认已经备份：

```bash
docker compose -f docker-compose-iotdb.yml down -v
```

## 初始化数据库

应用配置中使用的 IoTDB 数据库需要提前创建。进入 IoTDB CLI：

```bash
docker exec -it iotdb /iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root
```

按实际 profile 创建数据库，例如：

```sql
CREATE DATABASE rd3;
CREATE DATABASE rd3_dev;
SHOW DATABASES;
```

应用配置中的 JDBC URL 和 `iotdb.session.database` 需要与这里创建的数据库保持一致。

## 手动备份

备份脚本：`iotdb-backup.sh`

脚本使用 IoTDB 官方 `export-data.sh` 在线导出 TsFile，不停止 `iotdb-service`，也不直接读取 `iotdb-data` 数据卷。备份语义为：导出脚本开始时记录一个结束时间水位，只导出该时间水位之前的数据。

脚本会自动执行以下流程：

1. 检查 `iotdb` 容器是否运行。
2. 通过临时容器共享 `iotdb` 容器网络，连接 `127.0.0.1:6667`。
3. 使用 `export-data.sh -ft tsfile -sql_dialect table` 在线导出指定数据库。
4. 将导出目录压缩为 `.tsfile.tar.gz` 文件。
5. 生成 `.manifest` 备份元数据文件。
6. 清理超过保留天数的旧备份。

脚本默认配置：

| 配置 | 默认值 | 说明 |
|------|--------|------|
| `CONTAINER_NAME` | `iotdb` | IoTDB 容器名 |
| `IOTDB_IMAGE` | `apache/iotdb:2.0.6-standalone` | 用于执行导出工具的镜像 |
| `IOTDB_HOST` | `127.0.0.1` | 导出工具连接地址 |
| `IOTDB_PORT` | `6667` | 导出工具连接端口 |
| `IOTDB_USER` | `root` | 导出账号 |
| `IOTDB_PASSWORD` | `root` | 导出账号密码 |
| `IOTDB_DATABASE` | `rd3` | 备份数据库 |
| `BACKUP_ROOT` | `./backup` | 备份根目录 |
| `RETENTION_DAYS` | `7` | 备份保留天数 |

执行备份：

```bash
cd doc/deploy/iotdb
chmod +x iotdb-backup.sh
./iotdb-backup.sh
```

如需备份其他数据库，可通过环境变量覆盖：

```bash
IOTDB_DATABASE=rd3_dev ./iotdb-backup.sh
```

备份成功后会生成压缩文件：

```text
backup/iotdb_backup_yyyyMMdd_HHmmss.tsfile.tar.gz
backup/iotdb_backup_yyyyMMdd_HHmmss.manifest
```

备份日志：

```text
backup/backup.log
```

## 定时备份

建议使用 Linux `crontab` 配置定时任务。以下示例每天凌晨 03:00 执行一次备份。

编辑定时任务：

```bash
crontab -e
```

添加配置：

```cron
0 3 * * * cd /home/jia/workspace/java-template/doc/deploy/iotdb && /bin/bash iotdb-backup.sh >> /dev/null 2>&1
```

请根据服务器实际项目路径替换：

```text
/home/jia/workspace/java-template
```

查看当前定时任务：

```bash
crontab -l
```

查看定时任务执行日志：

```bash
tail -f doc/deploy/iotdb/backup/backup.log
```

## 恢复备份

在线备份生成的是 IoTDB TsFile 逻辑导出文件。恢复时需要先解压备份包，再使用 IoTDB `load` 命令或官方导入工具导入目标数据库。目标库可以提前创建，也可以在导入时由 IoTDB 创建。

以下示例将备份恢复到 `rd3_restore`，恢复前不需要删除 `iotdb-data` 数据卷：

```bash
cd doc/deploy/iotdb
mkdir -p backup/restore/iotdb_backup_yyyyMMdd_HHmmss
tar -xzf backup/iotdb_backup_yyyyMMdd_HHmmss.tsfile.tar.gz -C backup/restore/iotdb_backup_yyyyMMdd_HHmmss

docker run --rm \
  --network container:iotdb \
  -v "$(pwd)/backup/restore/iotdb_backup_yyyyMMdd_HHmmss:/restore:ro" \
  apache/iotdb:2.0.6-standalone \
  /iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root \
  -e "load '/restore/data' with ('database-name'='rd3_restore','on-success'='none')"
```

如果需要恢复到其他服务器，请先保持 IoTDB 版本一致，再导入 TsFile。

## 常用命令

```bash
# 启动
docker compose -f docker-compose-iotdb.yml up -d

# 重启
docker compose -f docker-compose-iotdb.yml restart iotdb-service

# 停止
docker compose -f docker-compose-iotdb.yml down

# 进入 IoTDB 命令行
docker exec -it iotdb /iotdb/sbin/start-cli.sh -h 127.0.0.1 -p 6667 -u root -pw root

# 查看日志
docker logs -f iotdb

# 查看数据卷
docker volume ls | grep iotdb-data

# 手动备份
./iotdb-backup.sh

# 备份其他数据库
IOTDB_DATABASE=rd3_dev ./iotdb-backup.sh
```

## 注意事项

- 生产环境应修改默认 `root/root` 账号密码，并同步更新应用配置。
- 应用配置中的 IoTDB 地址、端口、用户名、密码、数据库名需要与部署环境保持一致。
- `iotdb-backup.sh` 是在线逻辑导出，备份期间 IoTDB 服务不会停止，但导出会消耗查询、CPU、磁盘和网络资源，仍建议避开业务高峰执行。
- 在线备份不等同于文件级冷备，默认只保证导出结束时间水位之前的数据被纳入导出范围。
- 备份目录默认在项目目录下，建议定期同步到对象存储或其他服务器，避免单机故障导致数据和备份同时丢失。
