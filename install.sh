#!/bin/sh
set -e

# 加载共享库
. /etc/tailscale/common.sh
init_log

CONFIG_DIR="/etc/tailscale"
MIRROR_LIST_URL="https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/mirrors.txt"
SCRIPTS_TGZ_URL="https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/tailscale-openwrt-scripts.tar.gz"
EXPECTED_CHECKSUM="预先计算的tar.gz包的SHA256校验和"

# 创建目录
mkdir -p "$CONFIG_DIR"

# 下载资源
log "Downloading installation resources..."
if ! webget "/tmp/mirrors.txt" "$MIRROR_LIST_URL" "echoon"; then
    log "镜像列表下载失败"
    exit 1
fi

if ! webget "/tmp/tailscale-scripts.tar.gz" "$SCRIPTS_TGZ_URL" "echoon"; then
    log "脚本包下载失败"
    exit 1
fi

/etc/tailscale/test_mirrors.sh
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
