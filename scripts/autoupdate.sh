#!/bin/sh
set -e

# 加载共享库
. /etc/tailscale/common.sh

[ ! -f "$CONFIG_DIR/auto_update_enabled" ] && exit 0
safe_source "$INST_CONF"
safe_source "$NTF_CONF"

# 修改通知发送部分
send_update_notification() {
    local title=$1
    local message=$2
    if command -v curl >/dev/null 2>&1; then
        curl -sS "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
            -d "text=Tailscale$title" \
            -d "desp=$message\n时间: $(date '+%F %T')" > /dev/null
    else
        wget -qO- "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
            --post-data="text=Tailscale$title&desp=$message\n时间: $(date '+%F %T')" > /dev/null
    fi
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
