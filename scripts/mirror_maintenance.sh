#!/bin/sh
set -e

CONFIG_DIR="/etc/tailscale"
safe_source "$CONFIG_DIR/notify.conf"

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

# 清理旧记录
clean_scores() {
    awk -F, -v cutoff=$(date -d "30 days ago" +%s) \
        '$1 > cutoff' "$CONFIG_DIR/mirror_scores.txt" \
        > "$CONFIG_DIR/mirror_scores.tmp"
    mv "$CONFIG_DIR/mirror_scores.tmp" "$CONFIG_DIR/mirror_scores.txt"
}

# 移除无效镜像
prune_mirrors() {
    awk -F, '$3 == 0 {print $2}' "$CONFIG_DIR/mirror_scores.txt" | \
    while read -r bad_mirror; do
        if grep -q "$bad_mirror" "$CONFIG_DIR/mirrors.txt"; then
            echo "移除失效镜像: $bad_mirror"
            grep -v "$bad_mirror" "$CONFIG_DIR/mirrors.txt" \
                > "$CONFIG_DIR/mirrors.tmp"
            mv "$CONFIG_DIR/mirrors.tmp" "$CONFIG_DIR/mirrors.txt"
        fi
    done
}

# 主流程
clean_scores
if /etc/tailscale/test_mirrors.sh; then
    prune_mirrors
else
    send_notify "EMERGENCY" "镜像维护失败" "所有镜像均不可用"
    exit 1
fi
