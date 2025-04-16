#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"

# 停止服务
[ -f /etc/init.d/tailscale ] && {
    /etc/init.d/tailscale stop
    /etc/init.d/tailscale disable
    rm -f /etc/init.d/tailscale
}

# 删除所有文件
rm -rf \
    /usr/local/bin/tailscale \
    /usr/local/bin/tailscaled \
    /tmp/tailscale \
    /tmp/tailscaled \
    "$CONFIG_DIR"

# 清理cron
[ -f /etc/crontabs/root ] && {
    sed -i "\|$CONFIG_DIR/autoupdate.sh|d" /etc/crontabs/root
    /etc/init.d/cron restart
}

echo "Tailscale 已完全卸载"