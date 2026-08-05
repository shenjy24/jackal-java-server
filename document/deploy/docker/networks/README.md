# Docker 网络初始化

项目的 MySQL、IoTDB、应用服务和监控栈通过外部 Docker 网络 `rd_net` 通信。部署 Compose 服务前执行：

```bash
cd networks
chmod +x create-networks.sh
./create-networks.sh
```

脚本可重复执行：`rd_net` 已存在时不会修改或删除网络。

默认创建 bridge 网络 `rd_net`。需要自定义名称或 driver 时：

```bash
DOCKER_NETWORK_NAME=custom_net DOCKER_NETWORK_DRIVER=bridge ./create-networks.sh
```
