#!/usr/bin/env bash

set -Eeuo pipefail

NETWORK_NAME="${DOCKER_NETWORK_NAME:-rd_net}"
NETWORK_DRIVER="${DOCKER_NETWORK_DRIVER:-bridge}"

if ! command -v docker >/dev/null 2>&1; then
  echo "未找到 docker 命令，请先安装并启动 Docker。" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "当前用户无法连接 Docker，请检查 Docker 服务状态和用户权限。" >&2
  exit 1
fi

if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Docker 网络已存在，跳过创建: $NETWORK_NAME"
  exit 0
fi

echo "创建 Docker 网络: $NETWORK_NAME（driver: $NETWORK_DRIVER）"
docker network create --driver "$NETWORK_DRIVER" "$NETWORK_NAME"
docker network inspect "$NETWORK_NAME" >/dev/null

echo "Docker 网络创建完成: $NETWORK_NAME"
