#!/bin/bash

# 自动获取当前用户的 UID 和 GID 并导出为环境变量
export UID=$(id -u)
export GID=$(id -g)

echo ">>> 当前运行用户: UID=$UID, GID=$GID"

# 启动 Docker Compose
echo ">>> 正在启动 MySQL 容器..."
docker compose up -d

echo ">>> 启动完成！"