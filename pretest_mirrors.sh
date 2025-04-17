#!/bin/sh

set -e

# 加载共享库
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

CONFIG_DIR="/etc/tailscale"
mkdir -p "$CONFIG_DIR"
MIRROR_FILE_URL="https://ghproxy.ch3ng.top/https://github.com/CH3NGYZ/ts-test/raw/main/mirrors.txt"
TEST_URL="https://github.com/CH3NGYZ/ts-test/raw/main/test_connection.txt"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
TMP_VALID_MIRRORS="/tmp/valid_mirrors.tmp"

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

webget() {
    # 参数说明：
    # $1 下载路径
    # $2 下载URL
    # $3 输出控制 (echooff/echoon)
    # $4 重定向控制 (rediroff)
    local result=""
    
    if command -v curl >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && local progress='-s' || local progress='-#'
        [ -z "$4" ] && local redirect='-L' || local redirect=''
        result=$(curl -w %{http_code} -H "User-Agent: Mozilla/5.0 (curl-compatible)" --connect-timeout 10 $progress $redirect -ko "$1" "$2")
        [ -n "$(echo "$result" | grep -e ^2)" ] && result="200"
    else
        if command -v wget >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && local progress='-q' || local progress='--show-progress'
            [ "$4" = "rediroff" ] && local redirect='--max-redirect=0' || local redirect=''
            local certificate='--no-check-certificate'
            local timeout='--timeout=10'
            wget --header="User-Agent: Mozilla/5.0" $progress $redirect $certificate $timeout -O "$1" "$2"
            [ $? -eq 0 ] && result="200"
        else
            echo "Error: Neither curl nor wget available"
            return 1
        fi
    fi
    
    [ "$result" = "200" ] && return 0 || return 1
}

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

# 下载最新镜像列表
if webget "$MIRROR_LIST" "$MIRROR_FILE_URL" "echooff"; then
    echo "✅ 已更新镜像列表"
else
    echo "⚠️ 无法下载镜像列表，尝试使用旧版本（如果存在）"
    [ -s "$MIRROR_LIST" ] || {
        echo "❌ 没有可用镜像列表，且下载失败"
        manual_fallback
        exit 1
    }
fi


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
