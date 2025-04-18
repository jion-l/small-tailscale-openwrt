#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"
# 镜像测试函数（同之前）
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')  # 确保镜像地址以单个斜杠结尾
    local url_bin="${mirror}CH3NGYZ/small-tailscale-openwrt/releases/latest/download/$BIN_NAME"
    local url_sum="${mirror}CH3NGYZ/small-tailscale-openwrt/releases/latest/download/$SUM_NAME"

    log_info "🌐 测试镜像 $mirror, 最长需要 $TIME_OUT 秒..."

    rm -f "$BIN_PATH" "$SUM_PATH"
    local start=$(date +%s.%N)

    # 调试输出检查 URL 是否正确
    log_info "🌐 下载链接: $url_bin"
    log_info "🌐 校验文件链接: $url_sum"

    if timeout $TIME_OUT webget "$BIN_PATH" "$url_bin" "echooff" && timeout $TIME_OUT webget "$SUM_PATH" "$url_sum" "echooff"; then
        local sha_expected
        sha_expected=$(grep "$BIN_NAME" "$SUM_PATH" | awk '{print $1}')
        sha_actual=$(sha256sum "$BIN_PATH" | awk '{print $1}')
        if [ "$sha_expected" = "$sha_actual" ]; then
            local end=$(date +%s.%N)
            local dl_time=$(awk "BEGIN {printf \"%.2f\", $end - $start}")
            log_info "✅ $mirror 下载成功，用时 ${dl_time}s"
            echo "$(date +%s),$mirror,1,$dl_time,-" >> "$SCORE_FILE"
            echo "$dl_time $mirror" >> "$TMP_VALID_MIRRORS"
        else
            log_error "❌ $mirror 校验失败"
            echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
        fi
    else
        log_error "❌ $mirror 下载失败"
        echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
    fi

    rm -f "$BIN_PATH" "$SUM_PATH"
}


# 加载通知配置
[ -f $CONFIG_DIR/notify.conf ] && . $CONFIG_DIR/notify.conf

# 检查是否需要发送镜像失效通知
should_notify_mirror_fail() {
    if [ "$NOTIFY_MIRROR_FAIL" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# 主流程
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror"
done < "$MIRROR_LIST"

# 排序并保存有效镜像
if [ -s "$TMP_VALID_MIRRORS" ]; then
    sort -n "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
    log_info "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    # 如果启用镜像失效通知，发送通知
    if should_notify_mirror_fail; then
        send_notify "❌ 所有镜像均失效" "请手动配置代理"
    fi
    log_error "❌ 所有镜像均失效"
    touch "$VALID_MIRRORS"
fi

rm -f "$TMP_VALID_MIRRORS"
