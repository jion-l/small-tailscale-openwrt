#!/bin/sh

set -e

# 加载共享库
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

CONFIG_DIR="/etc/tailscale"
mkdir -p "$CONFIG_DIR"

TEST_URL="CH3NGYZ/ts-test/raw/main/test_connection.txt"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
TMP_VALID_MIRRORS="/tmp/valid_mirrors.tmp"

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

# 单个镜像测试函数
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')
    local tmp_out="/tmp/mirror_test.tmp"

    echo "测试 $mirror ..."

    local start=$(date +%s.%N)
    if webget "$tmp_out" "${mirror}${TEST_URL}" "echooff" && grep -q "test ok" "$tmp_out"; then
        local end=$(date +%s.%N)
        local latency=$(printf "%.2f" $(echo "$end - $start" | bc))
        local score=$(echo "10 - $latency * 2" | bc | awk '{printf "%.1f", $0}')
        echo "✅ $mirror  延迟: ${latency}s  评分: $score"
        echo "$(date +%s),$mirror,1,$latency,$score" >> "$SCORE_FILE"
        echo "$score $mirror" >> "$TMP_VALID_MIRRORS"
    else
        echo "❌ $mirror 连接失败"
        echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
    fi

    rm -f "$tmp_out"
}

# 手动选择镜像
manual_fallback() {
    send_notify "MIRROR_FAIL" "代理故障" "所有镜像均不可用！"

    echo "1) 手动输入镜像  2) 使用直连  3) 退出"
    while :; do
        read -p "请选择: " choice
        case $choice in
            1)
                read -p "输入镜像URL (如 https://mirror.example.com/https://github.com/): " mirror
                mirror=$(echo "$mirror" | sed 's|/*$|/|')
                if echo "$mirror" | grep -qE '^https?://'; then
                    echo "$mirror" >> "$MIRROR_LIST"
                    test_mirror "$mirror"
                    [ -s "$TMP_VALID_MIRRORS" ] && sort -rn "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
                    return 0
                else
                    echo "地址必须以 http:// 或 https:// 开头"
                fi
                ;;
            2)
                touch "$VALID_MIRRORS"  # 空文件表示直连
                return 1
                ;;
            3)
                exit 1
                ;;
        esac
    done
}

# 主流程
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror"
done < "$MIRROR_LIST"

if [ -s "$TMP_VALID_MIRRORS" ]; then
    sort -rn "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
    echo "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    manual_fallback
fi

rm -f "$TMP_VALID_MIRRORS"
