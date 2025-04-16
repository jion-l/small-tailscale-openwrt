#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
MIRROR_LIST_URL="https://github.3x25.com/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/mirrors.txt"
SCRIPTS_TGZ_URL="https://github.3x25.com/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/tailscale-openwrt-scripts.tar.gz"

# 创建目录
mkdir -p "$CONFIG_DIR"

# 下载资源
echo "📥 下载安装资源..."
curl -sSL -o "/tmp/mirrors.txt" "$MIRROR_LIST_URL"
curl -sSL -o "/tmp/tailscale-scripts.tar.gz" "$SCRIPTS_TGZ_URL"

# 解压脚本
echo "📦 解压脚本包..."
tar -xzf "/tmp/tailscale-scripts.tar.gz" -C "$CONFIG_DIR"
mv "/tmp/mirrors.txt" "$CONFIG_DIR/mirrors.txt"

# 设置权限
chmod +x "$CONFIG_DIR"/*.sh

# 初始化通知配置
cat > "$CONFIG_DIR/notify.conf" <<'EOF'
# 通知开关 (1=启用 0=禁用)
NOTIFY_UPDATE=1
NOTIFY_MIRROR_FAIL=1
NOTIFY_EMERGENCY=1

# Server酱SendKey
SERVERCHAN_KEY=""
EOF

echo "✅ 基础安装完成！请执行："
echo "   /etc/tailscale/setup.sh [options]"