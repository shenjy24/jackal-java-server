#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_deploy_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$SCRIPT_DIR/$1" ;;
    esac
}

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
        echo "  bash down.sh service-client"
        exit 1
        ;;
esac

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

APP_MODULE="$MODULE"
APP_CONTAINER_NAME="${APP_CONTAINER_NAME:-${MODULE}-${ENV}}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-${MODULE}-${ENV}}"
SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-$ENV}"
APP_LOG_DIR="$(resolve_deploy_path "${APP_LOG_DIR_BASE%/}/${MODULE}")"

export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE
export APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if ! command -v docker >/dev/null 2>&1; then
    log_error "未安装 Docker，请先安装 Docker"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    log_error "未检测到 Docker Compose v2，请先安装或升级 Docker Compose"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose.yml 不存在: $COMPOSE_FILE"
    exit 1
fi

log_info "停止模块: $MODULE"
log_info "停止容器: $APP_CONTAINER_NAME"
docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" down || {
    log_error "Docker Compose 停止失败"
    exit 1
}

log_info "停止完成: $APP_CONTAINER_NAME"
