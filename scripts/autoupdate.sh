#!/bin/sh
set -e

# 加载共享库
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

[ ! -f "$CONFIG_DIR/auto_update_enabled" ] && exit 0
safe_source "$INST_CONF"
safe_source "$NTF_CONF"
echo "正在自动更新..."
# 获取当前版本
current=$(cat "$CONFIG_DIR/current_version" 2>/dev/null || echo "unknown")

latest=$("$CONFIG_DIR/fetch_and_install.sh" --dry-run 2>/dev/null || echo "")
if [ -z "$latest" ]; then
    echo "🧭 AUTO-UPDATE: 无法获取最新版本，跳过更新"
    exit 0
fi

# 版本比对
[ "$latest" = "$current" ] && exit 0

# 执行更新
echo "🧭 AUTO-UPDATE: 发现新版本: $current -> $latest"
if "$CONFIG_DIR/fetch_and_install.sh" --version="$latest" --mode="$MODE"; then
    echo "✅ 自动更新成功，正在重启 tailscale..."
    /etc/init.d/tailscale restart
    send_notify "UPDATE" "更新成功" "✅ 从 $current 升级到 $latest"
    echo "$latest" > "$CONFIG_DIR/current_version"
else
    echo "❌ 自动更新失败！"
    send_notify "EMERGENCY" "更新失败" "❌ 当前: $current\n目标: $latest"
    exit 1
fi
