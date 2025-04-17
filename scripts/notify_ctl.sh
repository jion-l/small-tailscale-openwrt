#!/bin/sh

show_menu() {
    clear
    echo "🛠️ 通知配置管理"
    echo "--------------------------------"
    echo "1. 设置Server酱SendKey"
    echo "2. 切换更新通知开关"
    echo "3. 切换代理失败通知"
    echo "4. 切换紧急通知"
    echo "5. 发送测试通知"
    echo "6. 查看当前配置"
    echo "7. 退出"
    echo "--------------------------------"
}

edit_key() {
    echo "可以从 https://sct.ftqq.com/sendkey 获取 SendKey"
    read -p "请输入Server酱SendKey (留空禁用) : " key
    sed -i "s|^SERVERCHAN_KEY=.*|SERVERCHAN_KEY=\"$key\"|" "$NTF_CONF"
}

toggle_setting() {
    local setting=$1
    current=$(grep "^$setting=" "$NTF_CONF" | cut -d= -f2)
    new_value=$([ "$current" = "1" ] && echo "0" || echo "1")
    sed -i "s|^$setting=.*|$setting=$new_value|" "$NTF_CONF"
}

test_notify() {
    . "$NTF_CONF"
    [ -z "$SERVERCHAN_KEY" ] && {
        echo "❌ 未配置SendKey"
        return
    }
    curl -sS "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
        -d "text=Tailscale测试通知" \
        -d "desp=这是测试消息\n时间: $(date '+%F %T')"
    echo "✅ 测试通知已发送"
}

show_config() {
    echo "当前通知配置:"
    echo "--------------------------------"
    grep -v '^#' "$NTF_CONF" | while read -r line; do
        name=${line%%=*}
        value=${line#*=}
        case "$name" in
            NOTIFY_UPDATE)
                echo "更新通知: $([ "$value" = "1" ] && echo "✅" || echo "❌")" ;;
            NOTIFY_MIRROR_FAIL)
                echo "代理失败通知: $([ "$value" = "1" ] && echo "✅" || echo "❌")" ;;
            NOTIFY_EMERGENCY)
                echo "紧急通知: $([ "$value" = "1" ] && echo "✅" || echo "❌")" ;;
            SERVERCHAN_KEY)
                echo "SendKey: ${value:+"(已设置)"}" ;;
        esac
    done
    echo "--------------------------------"
}

# 主菜单
while :; do
    show_menu
    read -p "请选择 [1-7]: " choice
    case $choice in
        1) edit_key ;;
        2) toggle_setting "NOTIFY_UPDATE" ;;
        3) toggle_setting "NOTIFY_MIRROR_FAIL" ;;
        4) toggle_setting "NOTIFY_EMERGENCY" ;;
        5) test_notify ;;
        6) show_config ;;
        7) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    read -p "按回车键继续..."
done