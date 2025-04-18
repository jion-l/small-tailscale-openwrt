#!/bin/sh

# 检查并引入 /etc/tailscale/tools.sh 文件
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

# 如果配置文件不存在，初始化
if [ ! -f "$NTF_CONF" ]; then
    echo "⚠️ 未找到通知配置文件, 新建一个"
    mkdir -p "$(dirname "$NTF_CONF")"
    cat > "$NTF_CONF" <<EOF
# 通知配置文件
# 通知开关 (1=启用 0=禁用)
NOTIFY_UPDATE=1
NOTIFY_MIRROR_FAIL=1
NOTIFY_EMERGENCY=1

NOTIFY_SERVERCHAN=0
SERVERCHAN_KEY=""
NOTIFY_BARK=0
BARK_KEY=""
NOTIFY_NTFY=0
NTFY_KEY=""
EOF
fi

# 显示菜单
show_menu() {
    clear
    [ -f "$NTF_CONF" ] && . "$NTF_CONF"

    # 获取当前通知开关状态
    serverchan_status=$([ "$NOTIFY_SERVERCHAN" = "1" ] && echo "✅" || echo "❌")
    bark_status=$([ "$NOTIFY_BARK" = "1" ] && echo "✅" || echo "❌")
    ntfy_status=$([ "$NOTIFY_NTFY" = "1" ] && echo "✅" || echo "❌")
    
    # 获取其他通知配置
    update_status=$([ "$NOTIFY_UPDATE" = "1" ] && echo "✅" || echo "❌")
    mirror_fail_status=$([ "$NOTIFY_MIRROR_FAIL" = "1" ] && echo "✅" || echo "❌")
    emergency_status=$([ "$NOTIFY_EMERGENCY" = "1" ] && echo "✅" || echo "❌")

    echo "🛠️ 通知配置管理"
    echo "--------------------------------"
    echo "1. 设置Server酱SendKey      当前: ${SERVERCHAN_KEY}"
    echo "2. 设置Bark的设备码         当前: ${BARK_KEY}"
    echo "3. 设置ntfy的订阅码         当前: ${NTFY_KEY}"
    echo "4. 切换Server酱通知开关     状态: $serverchan_status"
    echo "5. 切换Bark通知开关         状态: $bark_status"
    echo "6. 切换ntfy通知开关         状态: $ntfy_status"
    echo "7. 切换更新成功通知开关      状态: $update_status"
    echo "8. 切换镜像失效通知开关      状态: $mirror_fail_status"
    echo "9. 切换更新失败通知开关      状态: $emergency_status"
    echo "10. 发送测试通知"
    echo "0. 退出"
    echo "--------------------------------"
}

# 设置Server酱的SendKey
edit_key() {
    echo "可以从 https://sct.ftqq.com/sendkey 获取 Server酱 SendKey"
    read -p "请输入 Server酱 SendKey: " key
    if grep -q "^SERVERCHAN_KEY=" "$NTF_CONF"; then
        sed -i "s|^SERVERCHAN_KEY=.*|SERVERCHAN_KEY=\"$key\"|" "$NTF_CONF"
    else
        echo "SERVERCHAN_KEY=\"$key\"" >> "$NTF_CONF"
    fi
}

# 设置Bark的设备码
edit_bark() {
    read -p "请输入 Bark 推送地址 (格式: https://自建或官方api.day.app/KEYxxxxxxx): " bark_key
    if grep -q "^BARK_KEY=" "$NTF_CONF"; then
        sed -i "s|^BARK_KEY=.*|BARK_KEY=\"$bark_key\"|" "$NTF_CONF"
    else
        echo "BARK_KEY=\"$bark_key\"" >> "$NTF_CONF"
    fi
}

# 设置ntfy的订阅码
edit_ntfy() {
    read -p "请输入 NTFY 订阅码: " ntfy_key
    if grep -q "^NTFY_KEY=" "$NTF_CONF"; then
        sed -i "s|^NTFY_KEY=.*|NTFY_KEY=\"$ntfy_key\"|" "$NTF_CONF"
    else
        echo "NTFY_KEY=\"$ntfy_key\"" >> "$NTF_CONF"
    fi
}

# 切换通知开关
toggle_setting() {
    local setting=$1
    if grep -q "^$setting=" "$NTF_CONF"; then
        current=$(grep "^$setting=" "$NTF_CONF" | cut -d= -f2)
        new_value=$([ "$current" = "1" ] && echo "0" || echo "1")
        sed -i "s|^$setting=.*|$setting=$new_value|" "$NTF_CONF"
    else
        # 如果配置项不存在，则默认设置为开启(1)
        echo "$setting=1" >> "$NTF_CONF"
    fi
}

# 修改通知开关的值
edit_notify_option() {
    local option=$1
    current_value=$(grep "^$option=" "$NTF_CONF" | cut -d= -f2)
    read -p "请输入 $option 当前值为 $current_value，设置新的值 (0=禁用, 1=启用): " new_value
    # 更新配置文件
    if [ "$new_value" = "0" ] || [ "$new_value" = "1" ]; then
        sed -i "s|^$option=.*|$option=$new_value|" "$NTF_CONF"
    else
        echo "❌ 无效输入，保留原值。"
    fi
}

# 测试通知
test_notify() {
    send_notify "✅ 这是测试消息" "时间: $(date '+%F %T')"
}

# 主菜单
while :; do
    show_menu
    read -p "请选择 [1-10]: " choice
    case $choice in
        0) exit 0 ;;
        1) edit_key ;;
        2) edit_bark ;;
        3) edit_ntfy ;;
        4) toggle_setting "NOTIFY_SERVERCHAN" ;;
        5) toggle_setting "NOTIFY_BARK" ;;
        6) toggle_setting "NOTIFY_NTFY" ;;
        7) edit_notify_option "NOTIFY_UPDATE" ;;
        8) edit_notify_option "NOTIFY_MIRROR_FAIL" ;;
        9) edit_notify_option "NOTIFY_EMERGENCY" ;;
        10) test_notify ;;
        *) echo "无效选择" ;;
    esac
done
