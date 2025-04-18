#!/bin/sh

[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh && safe_source "$INST_CONF"

# 如果没有传参，提示用户输入数字
if [ $# -eq 0 ]; then
    echo "当前自动更新状态: $AUTO_UPDATE"
    echo "当前版本: $(cat "$VERSION_FILE" 2>/dev/null || echo "未知")"
    echo "最新版本: $("$CONFIG_DIR/fetch_and_install.sh" --dry-run)"
    echo ""
    echo "请选择操作:"
    echo "  1. 启用自动更新"
    echo "  2. 禁用自动更新"
    echo -n "请输入数字 [1/2], 输入其他为退出: "
    read -r choice
else
    choice="$1"
fi

case "$choice" in
    1 | on)
        sed -i 's/^AUTO_UPDATE=.*/AUTO_UPDATE=true/' "$INST_CONF"
        echo "✅ 自动更新已启用"
        sleep 2
        ;;
    2 | off)
        sed -i 's/^AUTO_UPDATE=.*/AUTO_UPDATE=false/' "$INST_CONF"
        echo "🛑 自动更新已禁用"
        sleep 2
        ;;
    *)
        echo "用法: $0 [1|2 或 on|off]"
        exit 1
        ;;
esac
