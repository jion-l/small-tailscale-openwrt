#!/bin/sh
# /etc/tailscale/common.sh

CONFIG_DIR="/etc/tailscale"
LOG_FILE="/var/log/tailscale_install.log"

# 初始化日志系统
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
}

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %T')] $1" >> "$LOG_FILE"
}

# 安全加载配置文件
safe_source() {
    [ -f "$1" ] && . "$1"
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
            log "Error: Neither curl nor wget available"
            return 1
        fi
    fi
    
    [ "$result" = "200" ] && return 0 || return 1
}

# 发送通知
send_notify() {
    [ -z "$SERVERCHAN_KEY" ] && return
    local event_type="NOTIFY_$1"
    eval "local notify_enabled=\$$event_type"
    [ "$notify_enabled" = "1" ] || return

    if command -v curl >/dev/null 2>&1; then
        curl -sS "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
            -d "text=Tailscale$2" \
            -d "desp=$3\n时间: $(date '+%F %T')" > /dev/null
    else
        wget -qO- "https://sct.ftqq.com/$SERVERCHAN_KEY.send" \
            --post-data="text=Tailscale$2&desp=$3\n时间: $(date '+%F %T')" > /dev/null
    fi
    log "Sent notification: $1 - $2"
}