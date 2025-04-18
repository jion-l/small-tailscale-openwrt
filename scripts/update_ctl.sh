#!/bin/sh

[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh && safe_source "$INST_CONF"

# 如果没有传参，提示用户输入数字
if [ $# -eq 0 ]; then
    log_info "当前自动更新状态: $AUTO_UPDATE"
    log_info "当前版本: $(cat "$VERSION_FILE" 2>/dev/null || log_info "未知")"
    log_info "最新版本: $("$CONFIG_DIR/fetch_and_install.sh" --dry-run)"
    log_info "请选择操作:"
    log_info "  1. 启用自动更新"
    log_info "  2. 禁用自动更新"
    log_info "请输入数字 [1/2] 或 [on/off], 输入其他为退出: "
    read -r choice
else
    choice="$1"
fi

case "$choice" in
    1 | on)
        sed -i 's/^AUTO_UPDATE=.*/AUTO_UPDATE=true/' "$INST_CONF"
        log_info "✅ 自动更新已启用"
        ;;
    2 | off)
        sed -i 's/^AUTO_UPDATE=.*/AUTO_UPDATE=false/' "$INST_CONF"
        log_info "🛑 自动更新已禁用"
        ;;
    *)
        exit 1
        ;;
esac
