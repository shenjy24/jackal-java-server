#!/bin/bash

set -Eeuo pipefail

# ================= 用法 =================
# 内网部署只依赖本目录文件和上传的 jar，不依赖仓库源码。
# 指定模块（可选指定 jar 文件名，缺省时自动匹配 <module>*.jar）：
#   bash up.sh service-admin
#   bash up.sh service-client service-client-1.0.0-SNAPSHOT.jar

# ================= Path =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_deploy_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$SCRIPT_DIR/$1" ;;
    esac
}

# ================= Load config =================
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/app.env}"
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
        echo "请指定要部署的模块: service-admin 或 service-client"
        echo "  bash up.sh service-admin"
        exit 1
        ;;
esac

# ================= 部署参数 =================
ENV="${ENV:-prod}"
APP_LOG_DIR_BASE="${APP_LOG_DIR:-../logs}"
APP_MEMORY_LIMIT="${APP_MEMORY_LIMIT:-1G}"
APP_MEMORY_RESERVATION="${APP_MEMORY_RESERVATION:-512M}"
IMAGE_KEEP_COUNT="${IMAGE_KEEP_COUNT:-3}"
JAR_DIR="$(resolve_deploy_path "${JAR_DIR:-.}")"
RUNTIME_IMAGE="${RUNTIME_IMAGE:-eclipse-temurin:21-jre}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-$SCRIPT_DIR/Dockerfile}"
COMPOSE_FILE="${COMPOSE_FILE:-$SCRIPT_DIR/docker-compose.yml}"

if [ "$MODULE" = "service-admin" ]; then
    APP_PORT="${SERVICE_ADMIN_PORT:-18882}"
else
    APP_PORT="${SERVICE_CLIENT_PORT:-18881}"
fi
APP_LOG_DIR="$(resolve_deploy_path "${APP_LOG_DIR_BASE%/}/${MODULE}")"

APP_MODULE="$MODULE"
APP_CONTAINER_NAME="${MODULE}-${ENV}"
COMPOSE_PROJECT_NAME="${MODULE}-${ENV}"
SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-$ENV}"

# ================= 定位 jar =================
JAR_FILE="${2:-}"
if [ -n "$JAR_FILE" ] && [ "${JAR_FILE#/}" = "$JAR_FILE" ] && [ ! -f "$JAR_FILE" ]; then
    JAR_FILE="$(resolve_deploy_path "$JAR_FILE")"
fi

if [ -z "$JAR_FILE" ]; then
    mapfile -t JAR_FILES < <(find "$JAR_DIR" -maxdepth 1 -type f -name "${MODULE}*.jar" | sort)
    if [ "${#JAR_FILES[@]}" -eq 1 ]; then
        JAR_FILE="${JAR_FILES[0]}"
    else
        echo "请指定 $MODULE 的 jar 文件，例如："
        echo "  bash up.sh $MODULE ${MODULE}-1.0.0-SNAPSHOT.jar"
        echo
        echo "在 $JAR_DIR 中匹配到的 ${MODULE}*.jar：${JAR_FILES[*]:-<无>}"
        exit 1
    fi
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "jar 文件不存在: $JAR_FILE"
    exit 1
fi

if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Dockerfile 不存在: $DOCKERFILE_PATH"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "docker-compose.yml 不存在: $COMPOSE_FILE"
    exit 1
fi

if ! docker image inspect "$RUNTIME_IMAGE" >/dev/null 2>&1; then
    echo "运行时基础镜像不存在: $RUNTIME_IMAGE"
    echo "请先使用 docker load -i 加载对应的基础镜像 tar。"
    exit 1
fi

BUILD_TIME="$(date +%Y%m%d%H%M%S)"
IMAGE_VERSION="${ENV}-${BUILD_TIME}"
APP_IMAGE="${APP_IMAGE:-${MODULE}:${IMAGE_VERSION}}"

APP_UID="${SUDO_UID:-$(id -u)}"
APP_GID="${SUDO_GID:-$(id -g)}"
export APP_MODULE APP_CONTAINER_NAME COMPOSE_PROJECT_NAME SPRING_PROFILES_ACTIVE APP_PORT APP_LOG_DIR APP_MEMORY_LIMIT APP_MEMORY_RESERVATION APP_IMAGE APP_UID APP_GID

# ================= Build app image =================
BUILD_CONTEXT="$(mktemp -d)"
cleanup() {
    rm -rf "$BUILD_CONTEXT"
}
trap cleanup EXIT

cp "$JAR_FILE" "$BUILD_CONTEXT/app.jar"
cp "$DOCKERFILE_PATH" "$BUILD_CONTEXT/Dockerfile"

echo "部署模块: $MODULE"
echo "构建应用镜像: $APP_IMAGE"
docker build \
    --build-arg "APP_UID=$APP_UID" \
    --build-arg "APP_GID=$APP_GID" \
    --build-arg "JAR_FILE=app.jar" \
    -t "$APP_IMAGE" \
    "$BUILD_CONTEXT"

cat > "$SCRIPT_DIR/app-image-${MODULE}.env" <<EOF
APP_IMAGE=$APP_IMAGE
JAR_FILE=$JAR_FILE
BUILD_TIME=$BUILD_TIME
EOF

echo "应用镜像构建完成: $APP_IMAGE"

# ================= Start app =================
mkdir -p "$APP_LOG_DIR"
if [ "$(id -u)" -eq 0 ]; then
    chown "$APP_UID:$APP_GID" "$APP_LOG_DIR"
else
    echo "当前非 root 用户运行，跳过日志目录属主调整: $APP_LOG_DIR"
fi

echo "启动应用: $APP_IMAGE (端口 $APP_PORT)"
docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d --no-build app-server

echo "等待容器状态..."
sleep 5

if ! docker ps --filter "name=^/${APP_CONTAINER_NAME}$" --filter "status=running" --format "{{.Names}}" | grep -qx "$APP_CONTAINER_NAME"; then
    echo "容器未处于运行状态，请查看日志："
    echo "  docker logs --tail=200 $APP_CONTAINER_NAME"
    exit 1
fi

# 只保留当前模块当前环境最新的几个版本镜像；删除失败时提示但不中断部署。
echo "保留最新 $IMAGE_KEEP_COUNT 个 ${MODULE}:${ENV}-* 镜像版本..."
mapfile -t OLD_IMAGE_REFS < <(
    docker image ls "$MODULE" --format "{{.Repository}}:{{.Tag}}" \
        | awk -v env="$ENV" -v keep="$IMAGE_KEEP_COUNT" '$1 ~ ":" env "-" { count++; if (count > keep) print $1 }'
)

for IMAGE_REF in "${OLD_IMAGE_REFS[@]}"; do
    docker image rm "$IMAGE_REF" || echo "镜像删除失败，可能仍被容器使用: $IMAGE_REF"
done

echo "清除无用的悬空镜像..."
docker image prune -f

echo "内网启动完成: $APP_CONTAINER_NAME -> $APP_IMAGE"
echo "检查应用:"
echo "  curl -I http://127.0.0.1:$APP_PORT"
