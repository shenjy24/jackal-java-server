#!/bin/bash

# =========================================================================
# MySQL 8.4.10 离线一键自动化安装脚本 (Ubuntu 22.04 适用)
# 特点：全自动安装、应用自带 my.cnf 配置，并设置 root 默认密码为 123456
# =========================================================================

# 严格模式：任何命令失败则退出脚本
set -e

# 1. 定义文件名与路径变量
LIBAIO_DEB="libaio1_0.3.112-13build1_amd64.deb"
NUMACTL_DEB="numactl_2.0.14-3ubuntu2_amd64.deb"
MYSQL_TAR="mysql-8.4.10-linux-glibc2.17-x86_64.tar.xz"
LOCAL_MY_CNF="my.cnf" # 本地配置文件名

BASE_DIR="/usr/local/mysql"
DATA_DIR="/usr/local/mysql/data"
ROOT_PWD="123456"

echo "========================================="
echo " 开始进行 MySQL 8.4 离线自动化部署..."
echo "========================================="

# 2. 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本必须以 root 用户或使用 sudo 权限执行！"
    exit 1
fi

# 3. 检查所有必要文件是否存在（包含 my.cnf）
for file in "$LIBAIO_DEB" "$NUMACTL_DEB" "$MYSQL_TAR" "$LOCAL_MY_CNF"; do
    if [ ! -f "$file" ]; then
        echo "错误：未在当前目录下找到必要文件: $file"
        exit 1
    fi
done

# 4. 安装离线底层依赖
echo ">> 步骤 1: 正在安装底层依赖包 (.deb)..."
dpkg -i "$LIBAIO_DEB" "$NUMACTL_DEB"

# 5. 创建运行 MySQL 的系统用户和组
echo ">> 步骤 2: 正在创建 mysql 用户与组..."
if ! grep -q "^mysql:" /etc/group; then
    groupadd mysql
fi
if ! grep -q "^mysql:" /etc/passwd; then
    useradd -r -g mysql -s /bin/false mysql
fi

# 6. 解压主程序并移动到标准目录
echo ">> 步骤 3: 正在解压主程序压缩包 (请稍候)..."
tar -xf "$MYSQL_TAR"
EXTRACTED_DIR=$(tar -tf "$MYSQL_TAR" | head -1 | cut -f1 -d"/")

echo ">> 步骤 4: 正在移动文件到安装路径: $BASE_DIR"
if [ -d "$BASE_DIR" ]; then
    rm -rf "$BASE_DIR"
fi
mv "$EXTRACTED_DIR" "$BASE_DIR"

# 7. 创建数据存储目录并设置权限
echo ">> 步骤 5: 正在配置文件目录权限..."
mkdir -p "$DATA_DIR"
chown -R mysql:mysql "$BASE_DIR"
chmod 750 "$BASE_DIR"

# 8. 应用本地自带的 my.cnf
echo ">> 步骤 6: 正在应用本地的 $LOCAL_MY_CNF 配置文件..."
cp "$LOCAL_MY_CNF" /etc/my.cnf
# 设置标准的配置文件权限
chmod 644 /etc/my.cnf

# 9. 数据库安全无密码初始化
echo ">> 步骤 7: 正在初始化数据库 (采用安全无密码模式)..."
"$BASE_DIR/bin/mysqld" --initialize-insecure --user=mysql --basedir="$BASE_DIR" --datadir="$DATA_DIR"

# 10. 启动临时服务用以注入密码和远程权限
echo ">> 步骤 8: 启动临时服务以配置用户权限..."
"$BASE_DIR/support-files/mysql.server" start

# 给予服务 5 秒的稳定启动缓冲时间
sleep 5

echo ">> 步骤 9: 正在配置 root@localhost 与 root@% 的密码为 $ROOT_PWD..."
"$BASE_DIR/bin/mysql" -uroot --skip-password << EOF
-- 修改本地 root 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PWD';
-- 创建允许任意 IP 远程连接的 root 用户并设置密码
CREATE USER 'root'@'%' IDENTIFIED BY '$ROOT_PWD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
-- 刷新权限使配置立即生效
FLUSH PRIVILEGES;
EOF

echo ">> 步骤 10: 关闭临时服务，准备接管系统服务..."
"$BASE_DIR/support-files/mysql.server" stop

# 11. 配置 systemd 服务，支持开机自启和标准 systemctl 管理
echo ">> 步骤 11: 正在配置 systemd 服务单元..."
cat > /etc/systemd/system/mysqld.service << EOF
[Unit]
Description=MySQL Server (Offline Installed)
Documentation=man:mysqld(8)
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target

[Service]
User=mysql
Group=mysql
Type=forking
ExecStart=$BASE_DIR/support-files/mysql.server start
ExecStop=$BASE_DIR/support-files/mysql.server stop
TimeoutSec=300
PrivateTmp=false
EOF

# 12. 刷新服务并正式启动
echo ">> 步骤 12: 正在激活并运行 MySQL 服务..."
systemctl daemon-reload
systemctl enable mysqld
systemctl start mysqld

# 13. 追加系统环境变量
echo ">> 步骤 13: 正在配置环境变量..."
if ! grep -q "$BASE_DIR/bin" /etc/profile; then
    echo "export PATH=\$PATH:$BASE_DIR/bin" >> /etc/profile
fi

echo "========================================================="
echo "  MySQL 8.4.10 离线自动化安装成功！"
echo "========================================================="
echo " 用户名: root"
echo " 默认密码: $ROOT_PWD"
echo " 远程访问: 已开启 (允许从任意客户端连接)"
echo " 配置文件: 已使用本地提供的 my.cnf"
echo " 状态: 服务已自启并在后台运行中"
echo ""
echo " 请在当前终端执行以下命令使环境变量生效："
echo " source /etc/profile"
echo "========================================================="