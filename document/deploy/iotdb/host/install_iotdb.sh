#!/bin/bash

# =========================================================================
# IoTDB 2.0.6 离线安装脚本 (Ubuntu 22.04 适用)
# 默认保护已有数据；如需重装，使用 FORCE_REINSTALL=true 显式开启。
# =========================================================================

set -euo pipefail

IOTDB_VERSION="2.0.6"
IOTDB_ZIP="apache-iotdb-2.0.6-all-bin.zip"
JDK_TAR_PATTERN="jdk-21*.tar.gz"

BASE_DIR="/usr/local/iotdb"
SERVICE_USER="iotdb"
CONFIGNODE_SERVICE="iotdb-confignode"
DATANODE_SERVICE="iotdb-datanode"

DN_RPC_ADDRESS="${DN_RPC_ADDRESS:-127.0.0.1}"
DN_RPC_PORT="${DN_RPC_PORT:-6667}"
CN_INTERNAL_PORT="${CN_INTERNAL_PORT:-10710}"
CN_CONSENSUS_PORT="${CN_CONSENSUS_PORT:-10720}"
DN_INTERNAL_PORT="${DN_INTERNAL_PORT:-10730}"
DN_MPP_DATA_EXCHANGE_PORT="${DN_MPP_DATA_EXCHANGE_PORT:-10740}"
DN_SCHEMA_REGION_CONSENSUS_PORT="${DN_SCHEMA_REGION_CONSENSUS_PORT:-10750}"
DN_DATA_REGION_CONSENSUS_PORT="${DN_DATA_REGION_CONSENSUS_PORT:-10760}"

CONFIGNODE_MEMORY_SIZE="${CONFIGNODE_MEMORY_SIZE:-256M}"
DATANODE_MEMORY_SIZE="${DATANODE_MEMORY_SIZE:-512M}"
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-90}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""
JAVA_HOME_TO_USE="${JAVA_HOME:-}"

info() {
    echo ">> $*"
}

warn() {
    echo "警告：$*" >&2
}

die() {
    echo "错误：$*" >&2
    exit 1
}

cleanup() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

require_root() {
    if [ "$(id -u)" != "0" ]; then
        die "此脚本必须以 root 用户或 sudo 权限执行"
    fi
}

require_commands() {
    local missing=()
    local commands=(awk cat chmod chown command cp date dirname find grep groupadd head id mkdir mktemp mv readlink rm sed sleep sort ss systemctl tar tr unzip useradd)

    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        die "缺少必要命令: ${missing[*]}"
    fi
}

normalize_bool() {
    local name="$1"
    local value="$2"

    case "$value" in
        true|false)
            ;;
        *)
            die "$name 只能设置为 true 或 false，当前值: $value"
            ;;
    esac
}

check_startup_timeout() {
    case "$STARTUP_TIMEOUT" in
        ''|*[!0-9]*)
            die "STARTUP_TIMEOUT 必须为正整数，当前值: $STARTUP_TIMEOUT"
            ;;
    esac

    if [ "$STARTUP_TIMEOUT" -lt 1 ]; then
        die "STARTUP_TIMEOUT 必须大于 0，当前值: $STARTUP_TIMEOUT"
    fi
}

check_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "22.04" ]; then
            warn "当前系统为 ${PRETTY_NAME:-unknown}，脚本主要按 Ubuntu 22.04 验证"
        fi
    fi
}

check_required_files() {
    if [ ! -f "$SCRIPT_DIR/$IOTDB_ZIP" ]; then
        die "未在脚本目录找到 IoTDB 安装包: $SCRIPT_DIR/$IOTDB_ZIP"
    fi
}

java_major_version() {
    local java_bin="$1"
    local version
    local major

    version="$("$java_bin" -version 2>&1 | awk -F '"' '/version/ {print $2; exit}')"
    major="$(printf '%s' "$version" | awk -F. '{ if ($1 == "1") print $2; else print $1 }')"

    if [ -z "$major" ]; then
        echo "0"
    else
        echo "$major"
    fi
}

resolve_java_home_from_bin() {
    local java_bin="$1"
    local resolved

    resolved="$(readlink -f "$java_bin")"
    dirname "$(dirname "$resolved")"
}

find_local_jdk_tar() {
    find "$SCRIPT_DIR" -maxdepth 1 -type f -name "$JDK_TAR_PATTERN" | sort | head -n 1
}

install_local_jdk_if_needed() {
    local jdk_tar
    local extracted_dir
    local java_bin
    local major

    if command -v java >/dev/null 2>&1; then
        java_bin="$(command -v java)"
        major="$(java_major_version "$java_bin")"
        if [ "$major" -ge 21 ]; then
            JAVA_HOME_TO_USE="$(resolve_java_home_from_bin "$java_bin")"
            info "检测到 JDK $major: $JAVA_HOME_TO_USE"
            return
        fi
        warn "检测到 Java $major，当前脚本要求使用 JDK21"
    fi

    jdk_tar="$(find_local_jdk_tar)"
    if [ -z "$jdk_tar" ]; then
        die "未检测到 JDK21，也未在脚本目录找到 $JDK_TAR_PATTERN"
    fi

    info "步骤 1: 安装本地 JDK21: $jdk_tar"
    WORK_DIR="$(mktemp -d /tmp/iotdb-install.XXXXXX)"
    tar -xf "$jdk_tar" -C "$WORK_DIR"

    extracted_dir="$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$extracted_dir" ]; then
        die "无法识别 JDK 解压目录"
    fi

    JAVA_HOME_TO_USE="/usr/local/$(basename "$extracted_dir")"
    if [ ! -d "$JAVA_HOME_TO_USE" ]; then
        mv "$extracted_dir" "$JAVA_HOME_TO_USE"
    else
        info "$JAVA_HOME_TO_USE 已存在，复用该 JDK"
    fi

    major="$(java_major_version "$JAVA_HOME_TO_USE/bin/java")"
    if [ "$major" -lt 21 ]; then
        die "本地 JDK 版本低于 21: $JAVA_HOME_TO_USE"
    fi

    info "已准备 JDK $major: $JAVA_HOME_TO_USE"
}

check_ports_available() {
    local port
    local ports=("$DN_RPC_PORT" "$CN_INTERNAL_PORT" "$CN_CONSENSUS_PORT" "$DN_INTERNAL_PORT" "$DN_MPP_DATA_EXCHANGE_PORT" "$DN_SCHEMA_REGION_CONSENSUS_PORT" "$DN_DATA_REGION_CONSENSUS_PORT")

    for port in "${ports[@]}"; do
        if ss -ltn | awk '{print $4}' | grep -Eq "(:|\\.)${port}$"; then
            die "端口 $port 已被占用，请先停止现有服务或调整配置"
        fi
    done
}

backup_file_if_exists() {
    local file="$1"
    local backup

    if [ -e "$file" ]; then
        backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp -a "$file" "$backup"
        info "已备份 $file 到 $backup"
    fi
}

stop_existing_services_if_needed() {
    systemctl stop "$DATANODE_SERVICE" >/dev/null 2>&1 || true
    systemctl stop "$CONFIGNODE_SERVICE" >/dev/null 2>&1 || true
}

prepare_install_dir() {
    local backup_dir

    if [ -e "$BASE_DIR" ]; then
        if [ "$FORCE_REINSTALL" != "true" ]; then
            die "$BASE_DIR 已存在。为保护已有数据，脚本已停止；如确认重装，使用 FORCE_REINSTALL=true"
        fi

        stop_existing_services_if_needed
        backup_dir="${BASE_DIR}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$BASE_DIR" "$backup_dir"
        info "已将旧安装目录移动到 $backup_dir"
    fi
}

ensure_iotdb_user() {
    info "步骤 2: 创建 iotdb 系统用户与用户组"

    if ! grep -q "^${SERVICE_USER}:" /etc/group; then
        groupadd "$SERVICE_USER"
    fi
    if ! grep -q "^${SERVICE_USER}:" /etc/passwd; then
        useradd -r -g "$SERVICE_USER" -s /bin/false "$SERVICE_USER"
    fi
}

extract_iotdb() {
    local extracted_dir

    info "步骤 3: 解压 IoTDB 安装包"
    if [ -z "$WORK_DIR" ] || [ ! -d "$WORK_DIR" ]; then
        WORK_DIR="$(mktemp -d /tmp/iotdb-install.XXXXXX)"
    fi

    unzip -q "$SCRIPT_DIR/$IOTDB_ZIP" -d "$WORK_DIR"
    extracted_dir="$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d -name "apache-iotdb-*" | head -n 1)"
    if [ -z "$extracted_dir" ]; then
        extracted_dir="$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    fi
    if [ -z "$extracted_dir" ]; then
        die "无法识别 IoTDB 安装包解压目录"
    fi

    info "步骤 4: 移动文件到安装路径 $BASE_DIR"
    mv "$extracted_dir" "$BASE_DIR"
}

set_property() {
    local file="$1"
    local key="$2"
    local value="$3"
    local escaped_value

    escaped_value="$(printf '%s' "$value" | sed 's/[&#]/\\&/g')"

    if grep -Eq "^[#[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i -E "s#^[#[:space:]]*${key}[[:space:]]*=.*#${key}=${escaped_value}#" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

config_files_for_property() {
    local key="$1"
    local files=()

    case "$key" in
        schema_replication_factor|data_replication_factor)
            files+=("$BASE_DIR/conf/iotdb-system.properties")
            files+=("$BASE_DIR/conf/confignode-system.properties")
            files+=("$BASE_DIR/conf/datanode-system.properties")
            ;;
        cn_*)
            files+=("$BASE_DIR/conf/iotdb-system.properties")
            files+=("$BASE_DIR/conf/confignode-system.properties")
            ;;
        dn_*)
            files+=("$BASE_DIR/conf/iotdb-system.properties")
            files+=("$BASE_DIR/conf/datanode-system.properties")
            ;;
        *)
            files+=("$BASE_DIR/conf/iotdb-system.properties")
            ;;
    esac

    printf '%s\n' "${files[@]}"
}

set_iotdb_property() {
    local key="$1"
    local value="$2"
    local file
    local wrote=false

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            set_property "$file" "$key" "$value"
            wrote=true
        fi
    done < <(config_files_for_property "$key")

    if [ "$wrote" != "true" ]; then
        die "未找到可写入 $key 的 IoTDB 配置文件，请确认安装包结构"
    fi
}

set_memory_size() {
    local file="$1"
    local value="$2"

    if [ ! -f "$file" ]; then
        warn "未找到内存配置文件: $file"
        return
    fi

    if grep -Eq "^[#[:space:]]*MEMORY_SIZE=" "$file"; then
        sed -i -E "s|^[#[:space:]]*MEMORY_SIZE=.*|MEMORY_SIZE=\"${value}\"|" "$file"
    else
        echo "MEMORY_SIZE=\"${value}\"" >> "$file"
    fi
}

configure_iotdb() {
    info "步骤 5: 写入 IoTDB 单机配置"

    set_iotdb_property "schema_replication_factor" "1"
    set_iotdb_property "data_replication_factor" "1"
    set_iotdb_property "cn_internal_address" "127.0.0.1"
    set_iotdb_property "cn_internal_port" "$CN_INTERNAL_PORT"
    set_iotdb_property "cn_consensus_port" "$CN_CONSENSUS_PORT"
    set_iotdb_property "cn_seed_config_node" "127.0.0.1:${CN_INTERNAL_PORT}"
    set_iotdb_property "dn_rpc_address" "$DN_RPC_ADDRESS"
    set_iotdb_property "dn_rpc_port" "$DN_RPC_PORT"
    set_iotdb_property "dn_internal_address" "127.0.0.1"
    set_iotdb_property "dn_internal_port" "$DN_INTERNAL_PORT"
    set_iotdb_property "dn_mpp_data_exchange_port" "$DN_MPP_DATA_EXCHANGE_PORT"
    set_iotdb_property "dn_schema_region_consensus_port" "$DN_SCHEMA_REGION_CONSENSUS_PORT"
    set_iotdb_property "dn_data_region_consensus_port" "$DN_DATA_REGION_CONSENSUS_PORT"
    set_iotdb_property "dn_seed_config_node" "127.0.0.1:${CN_INTERNAL_PORT}"

    set_memory_size "$BASE_DIR/conf/confignode-env.sh" "$CONFIGNODE_MEMORY_SIZE"
    set_memory_size "$BASE_DIR/conf/datanode-env.sh" "$DATANODE_MEMORY_SIZE"
}

configure_dirs() {
    info "步骤 6: 配置目录权限"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$BASE_DIR"
    chmod 750 "$BASE_DIR"
}

install_systemd_services() {
    info "步骤 7: 配置 systemd 服务"
    backup_file_if_exists "/etc/systemd/system/${CONFIGNODE_SERVICE}.service"
    backup_file_if_exists "/etc/systemd/system/${DATANODE_SERVICE}.service"

    cat > "/etc/systemd/system/${CONFIGNODE_SERVICE}.service" << EOF
[Unit]
Description=Apache IoTDB ConfigNode
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=forking
Environment=IOTDB_HOME=$BASE_DIR
Environment=JAVA_HOME=$JAVA_HOME_TO_USE
Environment=PATH=$JAVA_HOME_TO_USE/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=$BASE_DIR
ExecStart=$BASE_DIR/sbin/start-confignode.sh -d
ExecStop=$BASE_DIR/sbin/stop-confignode.sh
Restart=on-failure
RestartSec=5
TimeoutSec=300
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/${DATANODE_SERVICE}.service" << EOF
[Unit]
Description=Apache IoTDB DataNode
After=network.target ${CONFIGNODE_SERVICE}.service
Requires=${CONFIGNODE_SERVICE}.service

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=forking
Environment=IOTDB_HOME=$BASE_DIR
Environment=JAVA_HOME=$JAVA_HOME_TO_USE
Environment=PATH=$JAVA_HOME_TO_USE/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=$BASE_DIR
ExecStart=$BASE_DIR/sbin/start-datanode.sh -d
ExecStop=$BASE_DIR/sbin/stop-datanode.sh
Restart=on-failure
RestartSec=5
TimeoutSec=300
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

wait_for_port() {
    local port="$1"
    local i

    for ((i = 1; i <= STARTUP_TIMEOUT; i++)); do
        if ss -ltn | awk '{print $4}' | grep -Eq "(:|\\.)${port}$"; then
            return 0
        fi
        sleep 1
    done

    return 1
}

start_systemd_services() {
    info "步骤 8: 启用并启动 IoTDB 服务"
    systemctl daemon-reload
    systemctl enable "$CONFIGNODE_SERVICE"
    systemctl enable "$DATANODE_SERVICE"
    systemctl start "$CONFIGNODE_SERVICE"

    if ! wait_for_port "$CN_INTERNAL_PORT"; then
        die "ConfigNode 在 ${STARTUP_TIMEOUT} 秒内未监听端口 $CN_INTERNAL_PORT，请查看 $BASE_DIR/logs"
    fi

    systemctl start "$DATANODE_SERVICE"
    if ! wait_for_port "$DN_RPC_PORT"; then
        die "DataNode 在 ${STARTUP_TIMEOUT} 秒内未监听 RPC 端口 $DN_RPC_PORT，请查看 $BASE_DIR/logs"
    fi
}

append_profile_path() {
    info "步骤 9: 配置 PATH"

    if ! grep -Fq "$BASE_DIR/sbin" /etc/profile; then
        {
            echo ""
            echo "# IoTDB offline install"
            echo "export IOTDB_HOME=$BASE_DIR"
            echo "export JAVA_HOME=$JAVA_HOME_TO_USE"
            echo "export PATH=\$PATH:$BASE_DIR/sbin:$JAVA_HOME_TO_USE/bin"
        } >> /etc/profile
    fi
}

main() {
    echo "========================================="
    echo " 开始进行 IoTDB ${IOTDB_VERSION} 离线部署"
    echo " 脚本目录: $SCRIPT_DIR"
    echo "========================================="

    normalize_bool "FORCE_REINSTALL" "$FORCE_REINSTALL"
    check_startup_timeout
    require_root
    require_commands
    check_os
    check_required_files
    install_local_jdk_if_needed
    prepare_install_dir
    check_ports_available
    ensure_iotdb_user
    extract_iotdb
    configure_iotdb
    configure_dirs
    install_systemd_services
    start_systemd_services
    append_profile_path

    echo "========================================================="
    echo " IoTDB ${IOTDB_VERSION} 离线安装成功"
    echo " 安装目录: $BASE_DIR"
    echo " Java Home: $JAVA_HOME_TO_USE"
    echo " RPC 地址: $DN_RPC_ADDRESS:$DN_RPC_PORT"
    echo " 服务名称: $CONFIGNODE_SERVICE, $DATANODE_SERVICE"
    echo " 生效 PATH: source /etc/profile"
    echo "========================================================="
}

main "$@"
