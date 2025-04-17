#!/bin/sh

CONFIG_DIR="/etc/tailscale"
safe_source "$CONFIG_DIR/install.conf"

case "$1" in
    on)
        touch "$CONFIG_DIR/auto_update_enabled"
        echo "✅ 自动更新已启用"
        ;;
    off)
        rm -f "$CONFIG_DIR/auto_update_enabled"
        echo "🛑 自动更新已禁用"
        ;;
    status)
        [ -f "$CONFIG_DIR/auto_update_enabled" ] && \
            echo "自动更新: 已启用" || \
            echo "自动更新: 已禁用"
        echo "当前版本: $(cat "$CONFIG_DIR/current_version" 2>/dev/null || echo "未知")"
        echo "最新版本: $("$CONFIG_DIR/fetch_and_install.sh" --dry-run)"
        ;;
    *)
        echo "用法: $0 [on|off|status]"
        exit 1
        ;;
esac