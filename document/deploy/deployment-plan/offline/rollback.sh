#!/bin/bash

set -Eeuo pipefail

# ================= Usage =================
# Roll back a module to a local historical image:
#   bash rollback.sh service-admin
#   bash rollback.sh service-admin 2
#   bash rollback.sh service-client service-client:prod-20260608120000

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
        echo "请指定要回滚的模块: service-admin 或 service-client"
        echo "  bash rollback.sh service-admin"
        echo "  bash rollback.sh service-client 2"
        exit 1
        ;;
esac

RELEASE_STATE_FILE="$SCRIPT_DIR/release-state-${MODULE}"
if [ -f "$RELEASE_STATE_FILE" ]; then
    set -a
    . "$RELEASE_STATE_FILE"
    set +a
fi

ENV="${ENV:-prod}"
APP_LOG_DIR_BASE="${APP_LOG_DIR:-../logs}"
APP_MEMORY_LIMIT="${APP_MEMORY_LIMIT:-1G}"
APP_MEMORY_RESERVATION="${APP_MEMORY_RESERVATION:-512M}"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"
TARGET_INPUT="${2:-}"

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

APP_UID="${SUDO_UID:-$(id -u)}"
APP_GID="${SUDO_GID:-$(id -g)}"

export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE
export APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION
export APP_UID APP_GID

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prerequisites() {
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
}

load_images() {
    mapfile -t IMAGE_REFS < <(
        docker image ls "$MODULE" --format "{{.Repository}}:{{.Tag}}" \
            | awk -v env="$ENV" '$1 ~ ":" env "-" { print $1 }'
    )

    if [ "${#IMAGE_REFS[@]}" -eq 0 ]; then
        log_error "未找到可回滚镜像: ${MODULE}:${ENV}-*"
        exit 1
    fi
}

list_images() {
    local current_image=""
    if docker container inspect "$APP_CONTAINER_NAME" >/dev/null 2>&1; then
        current_image="$(docker container inspect -f '{{.Config.Image}}' "$APP_CONTAINER_NAME")"
    fi

    echo ""
    echo "可回滚镜像列表："
    echo "----------------------------------------"
    for i in "${!IMAGE_REFS[@]}"; do
        local image_ref="${IMAGE_REFS[$i]}"
        local marker=""
        if [ "$image_ref" = "$current_image" ]; then
            marker=" <- 当前镜像"
        fi
        echo -e "  ${CYAN}$((i + 1))${NC}) $image_ref$marker"
    done
    echo "----------------------------------------"
    echo ""
}

resolve_target() {
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local idx=$((input - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#IMAGE_REFS[@]}" ]; then
            TARGET_IMAGE="${IMAGE_REFS[$idx]}"
        else
            log_error "序号超出范围: $input"
            exit 1
        fi
    else
        TARGET_IMAGE="$input"
    fi

    if ! docker image inspect "$TARGET_IMAGE" >/dev/null 2>&1; then
        log_error "目标镜像不存在: $TARGET_IMAGE"
        exit 1
    fi
}

prepare_log_dir() {
    mkdir -p "$APP_LOG_DIR"
    if [ "$(id -u)" -eq 0 ]; then
        chown "$APP_UID:$APP_GID" "$APP_LOG_DIR"
    else
        log_warn "当前非 root 用户运行，跳过日志目录属主调整: $APP_LOG_DIR"
    fi
}

rollback() {
    APP_IMAGE="$TARGET_IMAGE"
    export APP_IMAGE

    log_info "回滚模块 $MODULE 到镜像: $APP_IMAGE"
    docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d --no-build app-server

    sleep 5
    if ! docker ps --filter "name=^/${APP_CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -qx "$APP_CONTAINER_NAME"; then
        log_error "容器未处于运行状态，请查看日志: docker logs --tail=200 $APP_CONTAINER_NAME"
        exit 1
    fi
}

echo ""
echo "=========================================="
echo "  $MODULE - 容器镜像回滚"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

check_prerequisites
load_images
list_images

if [ -n "$TARGET_INPUT" ]; then
    resolve_target "$TARGET_INPUT"
else
    echo -n "请输入要回滚的镜像序号或完整镜像名: "
    read -r user_input
    resolve_target "$user_input"
fi

prepare_log_dir
rollback

echo ""
echo "=========================================="
log_info "回滚完成"
log_info "模块: $MODULE"
log_info "容器: $APP_CONTAINER_NAME"
log_info "镜像: $TARGET_IMAGE"
echo "=========================================="
