#!/usr/bin/env bash

set -Eeuo pipefail

# Offline bootstrap script for Docker Engine and Docker Compose.
# Put required packages under ./pkgs by default.

TECH_USER="${TECH_USER:-tech}"
PKG_DIR="${PKG_DIR:-pkgs}"
DOCKER_ARCHIVE="${DOCKER_ARCHIVE:-docker-29.5.3.tgz}"
DOCKER_COMPOSE_BINARY="${DOCKER_COMPOSE_BINARY:-docker-compose-linux-x86_64}"
DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-rd_net}"
IPTABLES_DEB_DIR="${IPTABLES_DEB_DIR:-$PKG_DIR}"
IPTABLES_DEB="${IPTABLES_DEB:-iptables_1.8.7-1ubuntu5.2_amd64.deb}"

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
OPT_DIR="${OPT_DIR:-/opt}"
DOCKER_BIN_DIR="${DOCKER_BIN_DIR:-$INSTALL_PREFIX/bin}"
DOCKER_COMPOSE_PLUGIN_DIR="${DOCKER_COMPOSE_PLUGIN_DIR:-$INSTALL_PREFIX/lib/docker/cli-plugins}"
DOCKER_BACKUP_DIR="${DOCKER_BACKUP_DIR:-$OPT_DIR/rd300-backups/docker}"
ROLLBACK_DOCKER="${ROLLBACK_DOCKER:-0}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  if ! command_exists "$1"; then
    echo "缺少必要命令: $1" >&2
    exit 1
  fi
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$SCRIPT_DIR/$1" ;;
  esac
}

require_file() {
  local file_path="$1"
  local label="$2"
  if [ ! -f "$file_path" ]; then
    echo "未找到${label}: $file_path" >&2
    exit 1
  fi
}

group_exists() {
  local group_name="$1"
  if command_exists getent; then
    getent group "$group_name" >/dev/null 2>&1
  elif [ -r /etc/group ]; then
    grep -q "^${group_name}:" /etc/group
  else
    return 1
  fi
}

is_ubuntu_2204() {
  if [ ! -r /etc/os-release ]; then
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  [ "${ID:-}" = "ubuntu" ] && [ "${VERSION_ID:-}" = "22.04" ]
}

install_iptables_if_missing() {
  if command_exists iptables; then
    log "iptables 已存在，跳过离线安装"
    iptables --version
    return
  fi

  log "未检测到 iptables，开始离线安装"
  if ! is_ubuntu_2204; then
    echo "当前脚本内置的 iptables 离线包仅适用于 Ubuntu 22.04；当前系统不匹配，请准备对应发行版的软件包。" >&2
    exit 1
  fi

  require_command dpkg
  require_command dpkg-deb
  require_file "$IPTABLES_DEB_DIR/$IPTABLES_DEB" "iptables 主安装包"

  local system_arch package_arch package_name
  system_arch="$(dpkg --print-architecture)"
  package_arch="$(dpkg-deb -f "$IPTABLES_DEB_DIR/$IPTABLES_DEB" Architecture)"
  package_name="$(dpkg-deb -f "$IPTABLES_DEB_DIR/$IPTABLES_DEB" Package)"
  if [ "$package_name" != "iptables" ]; then
    echo "iptables 主安装包不正确: $IPTABLES_DEB_DIR/$IPTABLES_DEB" >&2
    exit 1
  fi
  if [ "$package_arch" != "all" ] && [ "$package_arch" != "$system_arch" ]; then
    echo "iptables 安装包架构不匹配：服务器为 $system_arch，安装包为 $package_arch" >&2
    exit 1
  fi

  local deb_packages=()
  shopt -s nullglob
  deb_packages=("$IPTABLES_DEB_DIR"/*.deb)
  shopt -u nullglob
  if [ "${#deb_packages[@]}" -eq 0 ]; then
    echo "未在 $IPTABLES_DEB_DIR 找到任何 .deb 依赖包。" >&2
    exit 1
  fi

  # 目录内可同时放入 iptables 及其依赖包；dpkg 会在一次调用中完成解包和依赖配置。
  $SUDO dpkg -i "${deb_packages[@]}"
  if ! command_exists iptables; then
    echo "iptables 离线安装后仍不可用，请补齐 $IPTABLES_DEB_DIR 中缺失的依赖 .deb 包。" >&2
    exit 1
  fi
  iptables --version
}

create_tech_user() {
  log "创建用户: $TECH_USER"
  if id "$TECH_USER" >/dev/null 2>&1; then
    echo "用户 $TECH_USER 已存在，跳过创建。"
  else
    $SUDO useradd -m -s /bin/bash "$TECH_USER"
    echo "用户 $TECH_USER 已创建。如需密码登录，请后续执行: sudo passwd $TECH_USER"
  fi

  if command_exists usermod; then
    $SUDO usermod -aG sudo "$TECH_USER" 2>/dev/null || true
    $SUDO usermod -aG wheel "$TECH_USER" 2>/dev/null || true
  fi

  if [ -d /etc/sudoers.d ]; then
    printf '%s ALL=(ALL:ALL) ALL\n' "$TECH_USER" | $SUDO tee "/etc/sudoers.d/$TECH_USER" >/dev/null
    $SUDO chmod 0440 "/etc/sudoers.d/$TECH_USER"
  else
    echo "/etc/sudoers.d 不存在，请按需手动给 $TECH_USER 配置 sudo 权限。"
  fi
}

docker_binaries_match() {
  local source_dir="$1"
  local source_file target_file
  for source_file in "$source_dir"/*; do
    [ -f "$source_file" ] || continue
    target_file="$DOCKER_BIN_DIR/$(basename "$source_file")"
    if [ ! -f "$target_file" ] || ! cmp -s "$source_file" "$target_file"; then
      return 1
    fi
  done
  return 0
}

stop_docker_services() {
  if ! command_exists systemctl; then
    return
  fi

  log "停止 Docker/containerd，以便安全更新二进制"
  $SUDO systemctl stop docker.service 2>/dev/null || true
  $SUDO systemctl stop containerd.service 2>/dev/null || true
}

ensure_containerd_not_in_use() {
  local process_dir executable_path
  for process_dir in /proc/[0-9]*; do
    [ -e "$process_dir/exe" ] || continue
    executable_path="$(readlink -f "$process_dir/exe" 2>/dev/null || true)"
    if [ "$executable_path" = "$DOCKER_BIN_DIR/containerd" ]; then
      echo "containerd 仍在运行（PID ${process_dir##*/}），不能覆盖 $DOCKER_BIN_DIR/containerd。请先停止其所属服务。" >&2
      return 1
    fi
  done
}

backup_docker_binaries() {
  local source_dir="$1"
  local backup_dir="$DOCKER_BACKUP_DIR/$(date '+%Y%m%d%H%M%S')"
  local source_file target_file
  local backed_up=false

  for source_file in "$source_dir"/*; do
    [ -f "$source_file" ] || continue
    target_file="$DOCKER_BIN_DIR/$(basename "$source_file")"
    if [ -e "$target_file" ]; then
      if [ "$backed_up" = false ]; then
        $SUDO mkdir -p "$backup_dir"
        backed_up=true
      fi
      $SUDO cp -a "$target_file" "$backup_dir/"
    fi
  done

  if [ "$backed_up" = true ]; then
    log "已备份现有 Docker 二进制：$backup_dir"
  fi
}

copy_file_atomically() {
  local source_file="$1"
  local target_file="$2"
  local temp_file="${target_file}.rd300-install-$$"

  $SUDO cp "$source_file" "$temp_file"
  $SUDO chmod 0755 "$temp_file"
  $SUDO mv -f "$temp_file" "$target_file"
}

install_docker_binaries() {
  local source_dir="$1"
  local source_file
  for source_file in "$source_dir"/*; do
    [ -f "$source_file" ] || continue
    copy_file_atomically "$source_file" "$DOCKER_BIN_DIR/$(basename "$source_file")"
  done
}

install_docker_engine() {
  local archive_path="$1"
  log "安装 Docker Engine: $archive_path"

  require_file "$archive_path" "Docker 离线包"
  require_command tar

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  tar -xzf "$archive_path" -C "$tmp_dir"
  if [ ! -d "$tmp_dir/docker" ]; then
    echo "Docker 离线包结构不符合预期，未找到 docker/ 目录: $archive_path" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  $SUDO mkdir -p "$DOCKER_BIN_DIR"
  if docker_binaries_match "$tmp_dir/docker"; then
    log "Docker Engine 二进制已与离线包一致，跳过覆盖"
  else
    stop_docker_services
    ensure_containerd_not_in_use
    backup_docker_binaries "$tmp_dir/docker"
    if ! install_docker_binaries "$tmp_dir/docker"; then
      echo "Docker 二进制更新失败。旧版本已备份至 $DOCKER_BACKUP_DIR，可使用 ROLLBACK_DOCKER=1 恢复。" >&2
      rm -rf "$tmp_dir"
      return 1
    fi
  fi

  if ! group_exists docker; then
    $SUDO groupadd docker
  fi

  if command_exists usermod; then
    $SUDO usermod -aG docker "$TECH_USER" 2>/dev/null || true
  fi

  "$DOCKER_BIN_DIR/docker" --version
  rm -rf "$tmp_dir"
}

install_docker_compose() {
  local compose_path="$1"
  log "安装 Docker Compose: $compose_path"

  require_file "$compose_path" "Docker Compose 离线二进制"

  $SUDO mkdir -p "$DOCKER_COMPOSE_PLUGIN_DIR" "$INSTALL_PREFIX/bin"
  if [ -f "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose" ] && cmp -s "$compose_path" "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose"; then
    log "Docker Compose 已与离线包一致，跳过覆盖"
  else
    copy_file_atomically "$compose_path" "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose"
  fi
  $SUDO ln -sfn "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose" "$INSTALL_PREFIX/bin/docker-compose"

  "$DOCKER_BIN_DIR/docker" compose version || "$INSTALL_PREFIX/bin/docker-compose" version
}

rollback_docker_engine() {
  if [ ! -d "$DOCKER_BACKUP_DIR" ]; then
    echo "未找到 Docker 二进制备份目录：$DOCKER_BACKUP_DIR" >&2
    exit 1
  fi

  local backup_dir
  backup_dir="$(ls -dt "$DOCKER_BACKUP_DIR"/*/ 2>/dev/null | head -n 1 || true)"
  if [ -z "$backup_dir" ]; then
    echo "未找到可用于回滚的 Docker 二进制备份。" >&2
    exit 1
  fi

  log "回滚 Docker 二进制：$backup_dir"
  stop_docker_services
  ensure_containerd_not_in_use
  $SUDO mkdir -p "$DOCKER_BIN_DIR"

  local backup_file
  for backup_file in "$backup_dir"/*; do
    [ -f "$backup_file" ] || continue
    copy_file_atomically "$backup_file" "$DOCKER_BIN_DIR/$(basename "$backup_file")"
  done
}

create_docker_network() {
  log "创建 Docker 网络: $DOCKER_NETWORK_NAME"

  if $SUDO "$DOCKER_BIN_DIR/docker" network inspect "$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
    echo "Docker 网络 $DOCKER_NETWORK_NAME 已存在，跳过创建。"
    return
  fi

  $SUDO "$DOCKER_BIN_DIR/docker" network create --driver bridge "$DOCKER_NETWORK_NAME"
}

install_docker_systemd_units() {
  if ! command_exists systemctl; then
    echo "未找到 systemctl，请手动启动 dockerd。"
    return
  fi

  log "安装 Docker systemd 服务"
  $SUDO sh -c "cat > /etc/systemd/system/containerd.service" <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStart=$DOCKER_BIN_DIR/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

  $SUDO sh -c "cat > /etc/systemd/system/docker.service" <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target containerd.service
Wants=network-online.target
Requires=containerd.service

[Service]
Type=notify
ExecStart=$DOCKER_BIN_DIR/dockerd --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutStartSec=0
Restart=always
RestartSec=2
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now containerd
  $SUDO systemctl enable --now docker
}

main() {
  if [ "$(id -u)" -ne 0 ]; then
    require_command sudo
  fi

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PKG_DIR="$(resolve_path "$PKG_DIR")"
  IPTABLES_DEB_DIR="$(resolve_path "$IPTABLES_DEB_DIR")"

  if [ "$ROLLBACK_DOCKER" = "1" ]; then
    rollback_docker_engine
    install_docker_systemd_units
    exit 0
  fi

  local docker_archive_path="$PKG_DIR/$DOCKER_ARCHIVE"
  local compose_binary_path="$PKG_DIR/$DOCKER_COMPOSE_BINARY"

  create_tech_user
  install_iptables_if_missing
  install_docker_engine "$docker_archive_path"
  install_docker_systemd_units
  install_docker_compose "$compose_binary_path"
  create_docker_network

  echo
  echo "离线软件安装完成。"
  echo "如本次修改了 docker 用户组，请重新登录 $TECH_USER 后再直接执行 docker 命令。"
}

main "$@"
