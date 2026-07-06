#!/bin/bash

set -Eeuo pipefail

# ================= Usage =================
# Offline deployment only depends on this directory and uploaded jar artifacts.
# Build jar locally, upload jar, then run:
#   bash up.sh service-admin
#   bash up.sh service-client service-client-1.0.0-SNAPSHOT.jar

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
        echo "请指定要部署的模块: service-admin 或 service-client"
        echo "  bash up.sh service-admin"
        echo "  bash up.sh service-client service-client-1.0.0-SNAPSHOT.jar"
        exit 1
        ;;
esac

ENV="${ENV:-prod}"
APP_LOG_DIR_BASE="${APP_LOG_DIR:-../logs}"
APP_MEMORY_LIMIT="${APP_MEMORY_LIMIT:-1G}"
APP_MEMORY_RESERVATION="${APP_MEMORY_RESERVATION:-512M}"
IMAGE_KEEP_COUNT="${IMAGE_KEEP_COUNT:-3}"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-eclipse-temurin:21-jre}"
JAR_DIR="$(resolve_deploy_path "${JAR_DIR:-.}")"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-$SCRIPT_DIR/Dockerfile}"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"
JAR_INPUT="${2:-${JAR_FILE:-}}"

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
BUILD_TIME="$(date +%Y%m%d%H%M%S)"
BUILD_CONTEXT=""
RELEASE_STATE_FILE="$SCRIPT_DIR/release-state-${MODULE}"

APP_UID="${SUDO_UID:-$(id -u)}"
APP_GID="${SUDO_GID:-$(id -g)}"

export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE
export APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION
export APP_UID APP_GID

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

cleanup() {
    if [ -n "${BUILD_CONTEXT:-}" ] && [ -d "$BUILD_CONTEXT" ]; then
        rm -rf "$BUILD_CONTEXT"
    fi
}
trap cleanup EXIT

check_prerequisites() {
    if ! command -v docker >/dev/null 2>&1; then
        log_error "未安装 Docker，请先安装 Docker"
        exit 1
    fi

    if ! docker compose version >/dev/null 2>&1; then
        log_error "未检测到 Docker Compose v2，请先安装或升级 Docker Compose"
        exit 1
    fi

    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "Dockerfile 不存在: $DOCKERFILE_PATH"
        exit 1
    fi

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.yml 不存在: $COMPOSE_FILE"
        exit 1
    fi

    if ! docker image inspect "$RUNTIME_IMAGE" >/dev/null 2>&1; then
        log_error "运行时基础镜像不存在: $RUNTIME_IMAGE"
        log_info "请先使用 docker load -i 加载对应 JRE 镜像 tar。"
        exit 1
    fi
}

find_jar_package() {
    if [ -n "$JAR_INPUT" ]; then
        JAR_FILE="$(resolve_deploy_path "$JAR_INPUT")"
        return
    fi

    mapfile -t candidates < <(find "$JAR_DIR" -maxdepth 1 -type f -name "${MODULE}*.jar" | sort)
    if [ "${#candidates[@]}" -eq 1 ]; then
        JAR_FILE="${candidates[0]}"
        return
    fi

    log_error "未能唯一定位 $MODULE 的 jar 部署包"
    echo "请将本地 mvn package 产生的 jar 上传到: $JAR_DIR"
    echo "也可以显式指定: bash up.sh $MODULE <jar路径>"
    if [ "${#candidates[@]}" -gt 1 ]; then
        echo "匹配到多个候选 jar:"
        printf '  %s\n' "${candidates[@]}"
    fi
    exit 1
}

resolve_jar_file() {
    find_jar_package

    if [ ! -f "$JAR_FILE" ]; then
        log_error "jar 文件不存在: $JAR_FILE"
        exit 1
    fi

    IMAGE_VERSION="${ENV}-${BUILD_TIME}"
    APP_IMAGE="${APP_IMAGE:-${MODULE}:${IMAGE_VERSION}}"
    export APP_IMAGE
}

prepare_build_context() {
    resolve_jar_file
    BUILD_CONTEXT="$(mktemp -d)"

    cp "$JAR_FILE" "$BUILD_CONTEXT/app.jar"
    cp "$DOCKERFILE_PATH" "$BUILD_CONTEXT/Dockerfile"

    log_info "部署模块: $MODULE"
    log_info "部署包: $JAR_FILE"
    log_info "构建上下文: $BUILD_CONTEXT"
}

build_image() {
    log_info "构建应用镜像: $APP_IMAGE"
    docker build \
        --build-arg "RUNTIME_IMAGE=$RUNTIME_IMAGE" \
        --build-arg "APP_UID=$APP_UID" \
        --build-arg "APP_GID=$APP_GID" \
        --build-arg "JAR_FILE=app.jar" \
        -t "$APP_IMAGE" \
        "$BUILD_CONTEXT"

    cat > "$RELEASE_STATE_FILE" <<EOF
APP_IMAGE=$APP_IMAGE
JAR_FILE=$JAR_FILE
BUILD_TIME=$BUILD_TIME
EOF
}

prepare_log_dir() {
    mkdir -p "$APP_LOG_DIR"
    if [ "$(id -u)" -eq 0 ]; then
        chown "$APP_UID:$APP_GID" "$APP_LOG_DIR"
    else
        log_warn "当前非 root 用户运行，跳过日志目录属主调整: $APP_LOG_DIR"
    fi
}

deploy_container() {
    log_info "启动容器: $APP_CONTAINER_NAME"
    log_info "HTTP 端口: $APP_PORT -> 8080"

    docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d --no-build app-server

    sleep 5
    if ! docker ps --filter "name=^/${APP_CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -qx "$APP_CONTAINER_NAME"; then
        log_error "容器未处于运行状态，请查看日志: docker logs --tail=200 $APP_CONTAINER_NAME"
        exit 1
    fi
}

cleanup_old_images() {
    log_info "保留最新 $IMAGE_KEEP_COUNT 个 ${MODULE}:${ENV}-* 镜像版本..."
    mapfile -t old_image_refs < <(
        docker image ls "$MODULE" --format "{{.Repository}}:{{.Tag}}" \
            | awk -v env="$ENV" -v keep="$IMAGE_KEEP_COUNT" '$1 ~ ":" env "-" { count++; if (count > keep) print $1 }'
    )

    for image_ref in "${old_image_refs[@]}"; do
        docker image rm "$image_ref" || log_warn "镜像删除失败，可能仍被容器使用: $image_ref"
    done

    docker image prune -f
}

echo ""
echo "=========================================="
echo "  $MODULE - 内网容器部署"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

check_prerequisites
prepare_build_context
build_image
prepare_log_dir
deploy_container
cleanup_old_images

echo ""
echo "=========================================="
log_info "部署完成"
log_info "模块: $MODULE"
log_info "容器: $APP_CONTAINER_NAME"
log_info "镜像: $APP_IMAGE"
log_info "HTTP 端口: $APP_PORT"
echo "=========================================="
