#!/bin/bash

set -Eeuo pipefail

# ================= 用法 =================
# 停止指定模块容器：
#   bash down.sh service-admin
#   bash down.sh service-client

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/app.env}"
if [ -f "$ENV_FILE" ]; then
    set -a
    . "$ENV_FILE"
    set +a
fi

MODULE="${1:-${MODULE:-}}"
case "$MODULE" in
    service-admin|service-client) ;;
    *)
        echo "请指定要停止的模块: service-admin 或 service-client"
        echo "  bash down.sh service-admin"
        exit 1
        ;;
esac

ENV="${ENV:-prod}"
APP_LOG_DIR_BASE="${APP_LOG_DIR:-../logs}"
APP_MEMORY_LIMIT="${APP_MEMORY_LIMIT:-1G}"
APP_MEMORY_RESERVATION="${APP_MEMORY_RESERVATION:-512M}"

if [ "$MODULE" = "service-admin" ]; then
    APP_PORT="${SERVICE_ADMIN_PORT:-18882}"
else
    APP_PORT="${SERVICE_CLIENT_PORT:-18881}"
fi
APP_LOG_DIR="${APP_LOG_DIR_BASE%/}/${MODULE}"

APP_MODULE="$MODULE"
APP_CONTAINER_NAME="${MODULE}-${ENV}"
COMPOSE_PROJECT_NAME="${MODULE}-${ENV}"
SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-$ENV}"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"

export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION

if ! command -v docker >/dev/null 2>&1; then
    echo "未安装 Docker，请先安装 Docker"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "未检测到 Docker Compose v2，请先安装或升级 Docker Compose"
    exit 1
fi

echo "停止模块: $MODULE"
docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" down || { echo "Docker Compose 停止失败"; exit 1; }
echo "停止完成: $APP_CONTAINER_NAME"
