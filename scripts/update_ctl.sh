#!/bin/sh

[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh && safe_source "$INST_CONF"

# 如果没有传参，提示用户输入数字
if [ $# -eq 0 ]; then
    [ -f "$CONFIG_DIR/auto_update_enabled" ] && status_txt="已启用" || status_txt="已禁用"
    echo "当前自动更新状态: $status_txt"
    echo "当前版本: $(cat "$CONFIG_DIR/current_version" 2>/dev/null || echo "未知")"
    echo "最新版本: $("$CONFIG_DIR/fetch_and_install.sh" --dry-run)"
    echo ""
    echo "请选择操作:"
    echo "  1. 启用自动更新"
    echo "  2. 禁用自动更新"
    echo -n "请输入数字 [1/2]: "
    read -r choice
else
    choice="$1"
fi

case "$choice" in
    1 | on)
        touch "$CONFIG_DIR/auto_update_enabled"
        echo "✅ 自动更新已启用"
        ;;
    2 | off)
        rm -f "$CONFIG_DIR/auto_update_enabled"
        echo "🛑 自动更新已禁用"
        ;;
    *)
        echo "用法: $0 [1|2 或 on|off]"
        exit 1
        ;;
esac
