#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/app.env}"

echo ">>> 正在停止监控容器..."
docker compose --env-file "$ENV_FILE" -f "$SCRIPT_DIR/docker-compose-monitoring.yml" down

echo ">>> 停止完成"
