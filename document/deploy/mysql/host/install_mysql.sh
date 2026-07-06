#!/bin/bash

# =========================================================================
# MySQL 8.4.10 离线安装脚本 (Ubuntu 22.04 适用)
# 默认保护已有数据；如需重装，使用 FORCE_REINSTALL=true 显式开启。
# =========================================================================

set -euo pipefail

LIBAIO_DEB="libaio1_0.3.112-13build1_amd64.deb"
NUMACTL_DEB="numactl_2.0.14-3ubuntu2_amd64.deb"
MYSQL_TAR="mysql-8.4.10-linux-glibc2.17-x86_64.tar.xz"
LOCAL_MY_CNF="my.cnf"

BASE_DIR="/usr/local/mysql"
DATA_DIR="/usr/local/mysql/data"
MYSQL_PORT="3306"
MYSQL_SERVICE="mysqld"
ROOT_PWD="${ROOT_PWD:-123456}"
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"
ALLOW_REMOTE_ROOT="${ALLOW_REMOTE_ROOT:-false}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""
INIT_SQL_FILE=""

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
    if [ -n "$INIT_SQL_FILE" ] && [ -f "$INIT_SQL_FILE" ]; then
        rm -f "$INIT_SQL_FILE"
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
    local commands=(awk cat chmod chown command cp date dpkg find grep groupadd head id mkdir mktemp mv rm sed sleep systemctl tar useradd)

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

check_password_policy() {
    if [ "$ALLOW_REMOTE_ROOT" = "true" ] && [ "$ROOT_PWD" = "123456" ]; then
        die "开启远程 root 时必须通过 ROOT_PWD 设置非默认密码"
    fi

    if [ "$ROOT_PWD" = "123456" ]; then
        warn "当前使用默认 root 密码，仅建议本地临时环境使用"
    fi
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
    local file

    for file in "$LIBAIO_DEB" "$NUMACTL_DEB" "$MYSQL_TAR" "$LOCAL_MY_CNF"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            die "未在脚本目录找到必要文件: $SCRIPT_DIR/$file"
        fi
    done
}

check_port_available() {
    if command -v ss >/dev/null 2>&1; then
        if ss -ltn | awk '{print $4}' | grep -Eq "(:|\\.)${MYSQL_PORT}$"; then
            die "端口 $MYSQL_PORT 已被占用，请先停止现有服务或调整配置"
        fi
    else
        warn "未找到 ss 命令，跳过端口占用检查"
    fi
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

stop_existing_service_if_needed() {
    if systemctl list-unit-files "${MYSQL_SERVICE}.service" >/dev/null 2>&1; then
        systemctl stop "$MYSQL_SERVICE" >/dev/null 2>&1 || true
    fi
}

prepare_install_dir() {
    local backup_dir

    if [ -e "$BASE_DIR" ]; then
        if [ "$FORCE_REINSTALL" != "true" ]; then
            die "$BASE_DIR 已存在。为保护已有数据，脚本已停止；如确认重装，使用 FORCE_REINSTALL=true"
        fi

        stop_existing_service_if_needed
        backup_dir="${BASE_DIR}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$BASE_DIR" "$backup_dir"
        info "已将旧安装目录移动到 $backup_dir"
    fi
}

install_dependencies() {
    info "步骤 1: 安装离线依赖包"
    dpkg -i "$SCRIPT_DIR/$LIBAIO_DEB" "$SCRIPT_DIR/$NUMACTL_DEB"
}

ensure_mysql_user() {
    info "步骤 2: 创建 mysql 系统用户与用户组"

    if ! grep -q "^mysql:" /etc/group; then
        groupadd mysql
    fi
    if ! grep -q "^mysql:" /etc/passwd; then
        useradd -r -g mysql -s /bin/false mysql
    fi
}

extract_mysql() {
    local extracted_dir

    info "步骤 3: 解压 MySQL 安装包"
    WORK_DIR="$(mktemp -d /tmp/mysql-install.XXXXXX)"
    tar -xf "$SCRIPT_DIR/$MYSQL_TAR" -C "$WORK_DIR"

    extracted_dir="$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$extracted_dir" ]; then
        die "无法识别 MySQL 安装包解压目录"
    fi

    info "步骤 4: 移动文件到安装路径 $BASE_DIR"
    mv "$extracted_dir" "$BASE_DIR"
}

configure_dirs() {
    info "步骤 5: 配置目录权限"
    mkdir -p "$DATA_DIR"
    chown -R mysql:mysql "$BASE_DIR"
    chmod 750 "$BASE_DIR"
}

apply_mysql_config() {
    info "步骤 6: 应用 my.cnf 配置"
    backup_file_if_exists /etc/my.cnf
    cp "$SCRIPT_DIR/$LOCAL_MY_CNF" /etc/my.cnf
    chmod 644 /etc/my.cnf
}

initialize_database() {
    info "步骤 7: 初始化数据库"
    "$BASE_DIR/bin/mysqld" --initialize-insecure --user=mysql --basedir="$BASE_DIR" --datadir="$DATA_DIR"
}

wait_for_mysql() {
    local i

    for ((i = 1; i <= STARTUP_TIMEOUT; i++)); do
        if "$BASE_DIR/bin/mysqladmin" --protocol=socket -uroot --skip-password ping >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    return 1
}

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

configure_root_user() {
    local escaped_pwd

    info "步骤 8: 启动临时服务并配置 root 账户"
    "$BASE_DIR/support-files/mysql.server" start

    if ! wait_for_mysql; then
        "$BASE_DIR/support-files/mysql.server" stop >/dev/null 2>&1 || true
        die "MySQL 在 ${STARTUP_TIMEOUT} 秒内未就绪，请查看 $DATA_DIR/error.log"
    fi

    escaped_pwd="$(sql_escape "$ROOT_PWD")"
    INIT_SQL_FILE="$(mktemp /tmp/mysql-init-sql.XXXXXX)"
    chmod 600 "$INIT_SQL_FILE"

    {
        echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '$escaped_pwd';"
        if [ "$ALLOW_REMOTE_ROOT" = "true" ]; then
            echo "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$escaped_pwd';"
            echo "ALTER USER 'root'@'%' IDENTIFIED BY '$escaped_pwd';"
            echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
        fi
        echo "FLUSH PRIVILEGES;"
    } > "$INIT_SQL_FILE"

    "$BASE_DIR/bin/mysql" --protocol=socket -uroot --skip-password < "$INIT_SQL_FILE"
    rm -f "$INIT_SQL_FILE"
    INIT_SQL_FILE=""

    "$BASE_DIR/support-files/mysql.server" stop
}

install_systemd_service() {
    info "步骤 9: 配置 systemd 服务"
    backup_file_if_exists "/etc/systemd/system/${MYSQL_SERVICE}.service"

    cat > "/etc/systemd/system/${MYSQL_SERVICE}.service" << EOF
[Unit]
Description=MySQL Server (Offline Installed)
Documentation=man:mysqld(8)
After=network.target syslog.target

[Service]
User=mysql
Group=mysql
Type=forking
ExecStart=$BASE_DIR/support-files/mysql.server start
ExecStop=$BASE_DIR/support-files/mysql.server stop
Restart=on-failure
RestartSec=5
TimeoutSec=300
PrivateTmp=false

[Install]
WantedBy=multi-user.target
EOF
}

start_systemd_service() {
    info "步骤 10: 启用并启动 MySQL 服务"
    systemctl daemon-reload
    systemctl enable "$MYSQL_SERVICE"
    systemctl start "$MYSQL_SERVICE"
}

append_profile_path() {
    info "步骤 11: 配置 PATH"

    if ! grep -Fq "$BASE_DIR/bin" /etc/profile; then
        {
            echo ""
            echo "# MySQL offline install"
            echo "export PATH=\$PATH:$BASE_DIR/bin"
        } >> /etc/profile
    fi
}

main() {
    echo "========================================="
    echo " 开始进行 MySQL 8.4.10 离线部署"
    echo " 脚本目录: $SCRIPT_DIR"
    echo "========================================="

    normalize_bool "FORCE_REINSTALL" "$FORCE_REINSTALL"
    normalize_bool "ALLOW_REMOTE_ROOT" "$ALLOW_REMOTE_ROOT"
    check_password_policy
    check_startup_timeout
    require_root
    require_commands
    check_os
    check_required_files
    prepare_install_dir
    check_port_available
    install_dependencies
    ensure_mysql_user
    extract_mysql
    configure_dirs
    apply_mysql_config
    initialize_database
    configure_root_user
    install_systemd_service
    start_systemd_service
    append_profile_path

    echo "========================================================="
    echo " MySQL 8.4.10 离线安装成功"
    echo " 用户名: root"
    echo " 密码: 已按 ROOT_PWD 环境变量设置"
    echo " 远程 root: $ALLOW_REMOTE_ROOT"
    echo " 配置文件: /etc/my.cnf"
    echo " 服务名称: $MYSQL_SERVICE"
    echo " 生效 PATH: source /etc/profile"
    echo "========================================================="
}

main "$@"
