#!/bin/sh
# /etc/tailscale/tools.sh

CONFIG_DIR="/etc/tailscale"
LOG_FILE="/var/log/tailscale_install.log"
NTF_CONF="$CONFIG_DIR/notify.conf"
INST_CONF="$CONFIG_DIR/install.conf"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
TEST_URL="CH3NGYZ/ts-test/raw/main/test_connection.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
TMP_VALID_MIRRORS="/tmp/valid_mirrors.tmp"

# 初始化日志系统
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔧 INFO: $1"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔧 WARN: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1"
}

# 安全加载配置文件
safe_source() {
    local file="$1"
    if [ -f "$file" ] && [ -s "$file" ]; then
        . "$file"
    else
        log_warn "⚠️ 配置文件 $file 不存在或为空"
    fi
}


# 通用下载函数 (兼容curl/wget)
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

# 发送通知的通用函数
send_notify() {
    local title="$1"
    local content="$2"
    local extra_content="$3"

    . "$NTF_CONF"  # 引入配置文件

    # 检查是否有 curl 可用，如果没有则降级为 wget
    send_via_curl_or_wget() {
        local url="$1"
        local data="$2"
        local method="$3"
        local headers="$4"

        if command -v curl > /dev/null; then
            if [ "$method" = "POST" ]; then
                curl -sS -X POST "$url" -d "$data" -H "$headers"
            else
                curl -sS "$url" -d "$data" -H "$headers"
            fi
        elif command -v wget > /dev/null; then
            if [ "$method" = "POST" ]; then
                echo "$data" | wget --quiet --method=POST --body-file=- --header="$headers" "$url"
            else
                wget --quiet --post-data="$data" --header="$headers" "$url"
            fi
        else
            echo "❌ curl 和 wget 都不可用，无法发送通知"
            return 1
        fi
    }

    # 仅在Server酱开关启用时发送通知
    if [ "$NOTIFY_SERVERCHAN" = "1" ] && [ -n "$SERVERCHAN_KEY" ]; then
        # 使用 printf 来确保换行符被正确处理
        data="text=$title&desp=$(printf "%s\n%s" "$content" "$extra_content")"
        send_via_curl_or_wget "https://sctapi.ftqq.com/$SERVERCHAN_KEY.send" "$data" "POST" && echo "✅ Server酱 通知已发送"
    fi

    # 仅在Bark开关启用时发送通知
    if [ "$NOTIFY_BARK" = "1" ] && [ -n "$BARK_KEY" ]; then
        # 使用 printf 来确保换行符被正确处理
        data="$(printf "%s\n%s" "$content" "$extra_content")"
        send_via_curl_or_wget "https://api.day.app/$BARK_KEY/$title/$data" "$data" "GET" && echo "✅ Bark 通知已发送"
    fi

    # 仅在ntfy开关启用时发送通知
    if [ "$NOTIFY_NTFY" = "1" ] && [ -n "$NTFY_KEY" ]; then
        # 使用 printf 来确保换行符被正确处理
        data="$(printf "%s\n%s" "$content" "$extra_content")"
        headers="Title: $title"
        send_via_curl_or_wget "https://ntfy.sh/$NTFY_KEY" "$data" "POST" "$headers" && echo "✅ NTFY 通知已发送"
    fi

    if [ "$NOTIFY_SERVERCHAN" != "1" ] && [ "$NOTIFY_BARK" != "1" ] && [ "$NOTIFY_NTFY" != "1" ]; then
        echo "❌ 未启用任何通知方式"
    fi
}

