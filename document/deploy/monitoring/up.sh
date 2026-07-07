#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/app.env}"

if [ -f "$ENV_FILE" ]; then
    set -a
    . "$ENV_FILE"
    set +a
fi

if ! docker network inspect rd_net >/dev/null 2>&1; then
    echo ">>> 未找到 Docker 网络 rd_net，正在创建..."
    docker network create rd_net >/dev/null
fi

echo ">>> 正在启动监控容器..."
docker compose --env-file "$ENV_FILE" -f "$SCRIPT_DIR/docker-compose-monitoring.yml" up -d

echo ">>> 启动完成"
