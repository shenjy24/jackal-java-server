#!/bin/bash

# 开启严格模式：遇到错误、未定义变量或管道错误立即退出
set -Eeuo pipefail

# 脚本、配置和 docker-compose 文件均放在当前目录下
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 如需调整配置，直接修改同目录下的 app.env。
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/app.env}"
if [ -f "$ENV_FILE" ]; then
    set -a
    . "$ENV_FILE"
    set +a
fi

# 启动 Docker Compose
echo ">>> 正在启动 MySQL 容器..."
docker compose --env-file "$ENV_FILE" -f "$SCRIPT_DIR/docker-compose-mysql.yml" up -d

echo ">>> 启动完成！"
