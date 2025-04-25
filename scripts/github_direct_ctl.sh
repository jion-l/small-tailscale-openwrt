#!/bin/sh

[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh && safe_source "$INST_CONF"


# 如果没有传参，提示用户输入数字
if [ $# -eq 0 ]; then
    if [ "$GITHUB_DIRECT" = "true" ]; then
        log_info "🔄  当前直连GITHUB状态: 🟢"  # 绿色
    else
        log_info "🔄  当前直连GITHUB状态: 🔴"  # 红色
    fi

    log_info "🎛️  请选择操作:"
    log_info "       1). 使用直连 🟢"
    log_info "       2). 使用代理 🔴"
    log_info "⏳  请输入数字 [1/2] 或 [on/off], 输入其他为退出: " 1
    read -r choice
else
    choice="$1"
fi

case "$choice" in
    1 | on)
        sed -i 's/^GITHUB_DIRECT=.*/GITHUB_DIRECT=true/' "$INST_CONF"
        log_info "🟢  已设置使用直连"
        ;;
    2 | off)
        sed -i 's/^GITHUB_DIRECT=.*/GITHUB_DIRECT=false/' "$INST_CONF"
        log_info "🔴  已设置使用代理"
        ;;
    *)
        exit 1
        ;;
esac
