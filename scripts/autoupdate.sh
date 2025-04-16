#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
[ ! -f "$CONFIG_DIR/auto_update_enabled" ] && exit 0
[ -f "$CONFIG_DIR/install.conf" ] && . "$CONFIG_DIR/install.conf"
[ -f "$CONFIG_DIR/notify.conf" ] && . "$CONFIG_DIR/notify.conf"

# 发送通知
send_notify() {
    [ -z "$SERVERCHAN_KEY" ] && return
    local event_type="NOTIFY_$1"
    eval "local notify_enabled=\$$event_type"
    [ "$notify_enabled" = "1" ] || return

    curl -sS "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
        -d "text=Tailscale$2" \
        -d "desp=$3\n时间: $(date '+%F %T')" > /dev/null
}

# 获取当前版本
current=$(cat "$CONFIG_DIR/current_version" 2>/dev/null || echo "unknown")
latest=$("$CONFIG_DIR/fetch_and_install.sh" --dry-run)

# 版本比对
[ "$latest" = "$current" ] && exit 0

# 执行更新
echo "🔄 发现新版本: $current -> $latest"
if "$CONFIG_DIR/fetch_and_install.sh" --version="$latest" --mode="$MODE"; then
    /etc/init.d/tailscale restart
    send_notify "UPDATE" "更新成功" "✅ 从 $current 升级到 $latest"
else
    send_notify "EMERGENCY" "更新失败" "❌ 当前: $current\n目标: $latest"
    exit 1
fi