#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
TEST_URL="CH3NGYZ/ts-test/raw/main/test_connection.txt"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
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

# 测试镜像
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')
    echo -n "测试 $mirror ... "
    
    local start=$(date +%s.%N)
    if curl -m 5 -fsSL "${mirror}${TEST_URL}" | grep -q "test ok"; then
        local end=$(date +%s.%N)
        local latency=$(printf "%.2f" $(echo "$end - $start" | bc))
        local score=$(echo "10 - $latency * 2" | bc | awk '{printf "%.1f", $0}')
        echo "✅ ${latency}s (评分: $score)"
        echo "$(date +%s),$mirror,1,$latency,$score" >> "$SCORE_FILE"
        echo "$score $mirror"
        return 0
    else
        echo "❌ 失败"
        echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
        return 1
    fi
}

# 手动恢复
manual_fallback() {
    send_notify "MIRROR_FAIL" "代理故障" "所有镜像均不可用！"
    
    echo "1) 手动输入镜像  2) 使用直连  3) 退出"
    while :; do
        read -p "请选择: " choice
        case $choice in
            1)
                read -p "输入镜像URL (如 https://mirror.example.com/): " mirror
                mirror=$(echo "$mirror" | sed 's|/*$|/|')
                if [[ "$mirror" =~ ^https?:// ]]; then
                    echo "$mirror" >> "$MIRROR_LIST"
                    test_mirror "$mirror" && return 0
                else
                    echo "地址必须以 http:// 或 https:// 开头"
                fi
                ;;
            2)
                touch "$VALID_MIRRORS" # 创建空文件表示直连
                return 1
                ;;
            3)
                exit 1
                ;;
        esac
    done
}

# 主流程
> "$VALID_MIRRORS.tmp"
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror" >> "$VALID_MIRRORS.tmp" &
done < "$MIRROR_LIST"
wait

[ -s "$VALID_MIRRORS.tmp" ] && {
    sort -rn "$VALID_MIRRORS.tmp" | awk '{print $2}' > "$VALID_MIRRORS"
    echo "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
} || manual_fallback

rm -f "$VALID_MIRRORS.tmp"