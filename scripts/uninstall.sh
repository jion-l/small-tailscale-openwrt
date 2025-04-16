#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"

echo "🛑 开始卸载Tailscale..."
[ -f /etc/init.d/tailscale ] && {
    /etc/init.d/tailscale stop
    /etc/init.d/tailscale disable
    rm -f /etc/init.d/tailscale
}

echo "🗑️ 删除程序文件..."
rm -f \
    /usr/local/bin/tailscale \
    /usr/local/bin/tailscaled \
    /usr/bin/tailscale \
    /usr/bin/tailscaled \
    /tmp/tailscale \
    /tmp/tailscaled

echo "🧹 清理定时任务..."
sed -i "\|$CONFIG_DIR/|d" /etc/crontabs/root
/etc/init.d/cron restart

echo "🔐 保留以下配置："
echo "   - 镜像列表: $CONFIG_DIR/mirrors.txt"
echo "   - 通知配置: $CONFIG_DIR/notify.conf"
echo "   - 版本记录: $CONFIG_DIR/current_version"

echo "🎉 卸载完成！如需完全清理，请手动删除 $CONFIG_DIR 目录"
