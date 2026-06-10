#!/bin/bash

set -Eeuo pipefail

# ================= 用法 =================
# 回滚指定模块到指定历史镜像：
#   bash rollback.sh service-admin service-admin:prod-20260608120000

# ================= Path =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_deploy_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$SCRIPT_DIR/$1" ;;
    esac
}

# ================= Load config =================
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/deploy.env}"
if [ -f "$ENV_FILE" ]; then
    set -a
    . "$ENV_FILE"
    set +a
fi

# ================= 模块校验 =================
MODULE="${1:-${MODULE:-}}"
case "$MODULE" in
    service-admin|service-client) ;;
    *)
        echo "请指定要回滚的模块: service-admin 或 service-client"
        echo "  bash rollback.sh service-admin <image>"
        exit 1
        ;;
esac

# ================= 回滚参数 =================
ENV="${ENV:-prod}"
APP_LOG_DIR_BASE="${APP_LOG_DIR:-../logs}"
APP_MEMORY_LIMIT="${APP_MEMORY_LIMIT:-1G}"
APP_MEMORY_RESERVATION="${APP_MEMORY_RESERVATION:-512M}"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"

if [ "$MODULE" = "service-admin" ]; then
    APP_PORT="${SERVICE_ADMIN_PORT:-18882}"
else
    APP_PORT="${SERVICE_CLIENT_PORT:-18881}"
fi
APP_LOG_DIR="$(resolve_deploy_path "${APP_LOG_DIR_BASE%/}/${MODULE}")"

TARGET_IMAGE="${2:-}"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "docker-compose.yml 不存在: $COMPOSE_FILE"
    exit 1
fi

if [ -z "$TARGET_IMAGE" ]; then
    echo "请指定要回滚的镜像，例如："
    echo "  bash rollback.sh ${MODULE} ${MODULE}:${ENV}-20260608120000"
    echo
    echo "当前本机可用的 ${MODULE}:${ENV}-* 镜像："
    docker image ls "$MODULE" --format "  {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}" \
        | awk -v env="$ENV" '$1 ~ ":" env "-" { print }'
    exit 1
fi

if ! docker image inspect "$TARGET_IMAGE" >/dev/null 2>&1; then
    echo "镜像不存在: $TARGET_IMAGE"
    echo "可用镜像："
    docker image ls "$MODULE" --format "  {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}\t{{.Size}}" \
        | awk -v env="$ENV" '$1 ~ ":" env "-" { print }'
    exit 1
fi

APP_MODULE="$MODULE"
APP_CONTAINER_NAME="${MODULE}-${ENV}"
COMPOSE_PROJECT_NAME="${MODULE}-${ENV}"
SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-$ENV}"
APP_IMAGE="$TARGET_IMAGE"

export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION APP_IMAGE

APP_UID="${SUDO_UID:-$(id -u)}"
APP_GID="${SUDO_GID:-$(id -g)}"
export APP_UID APP_GID

mkdir -p "$APP_LOG_DIR"
if [ "$(id -u)" -eq 0 ]; then
    chown "$APP_UID:$APP_GID" "$APP_LOG_DIR"
else
    echo "当前非 root 用户运行，跳过日志目录属主调整: $APP_LOG_DIR"
fi

echo "回滚模块 $MODULE 到镜像: $APP_IMAGE"
docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d --no-build app-server

echo "等待容器状态..."
sleep 5

if ! docker ps --filter "name=^/${APP_CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -qx "$APP_CONTAINER_NAME"; then
    echo "容器未处于运行状态，请查看日志："
    echo "  docker logs --tail=200 $APP_CONTAINER_NAME"
    exit 1
fi

echo "回滚完成: $APP_CONTAINER_NAME -> $APP_IMAGE"
