#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

# 镜像测试函数（同之前）
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')
    local tailscale_url="${mirror}CH3NGYZ/ts-test/releases/latest/download/tailscaled_linux_amd64"
    local sha_url="${mirror}CH3NGYZ/ts-test/releases/latest/download/SHA256SUMS.txt"
    local tmp_bin="/tmp/tailscaled_test"
    local tmp_sha="/tmp/sha256sums_test"
    local latency

    echo "测试 $mirror ..."

    local start=$(date +%s.%N)

    if webget "$tmp_bin" "$tailscale_url" "echooff" && webget "$tmp_sha" "$sha_url" "echooff"; then
        local expected_sha=$(grep 'tailscaled_linux_amd64' "$tmp_sha" | awk '{print $1}')
        local actual_sha=$(sha256sum "$tmp_bin" | awk '{print $1}')

        if [ "$expected_sha" = "$actual_sha" ]; then
            local end=$(date +%s.%N)
            latency=$(printf "%.2f" $(echo "$end - $start" | bc))
            echo "✅ $mirror 校验通过，延迟: ${latency}s"
            echo "$(date +%s),$mirror,1,$latency" >> "$SCORE_FILE"
            echo "$latency $mirror" >> "$TMP_VALID_MIRRORS"
        else
            echo "❌ $mirror 校验失败"
            echo "$(date +%s),$mirror,0,998" >> "$SCORE_FILE"
        fi
    else
        echo "❌ $mirror 下载失败"
        echo "$(date +%s),$mirror,0,999" >> "$SCORE_FILE"
    fi

    rm -f "$tmp_bin" "$tmp_sha"
}

# 加载通知配置
[ -f /etc/tailscale/notify.conf ] && . /etc/tailscale/notify.conf

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
    echo "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    # 如果启用镜像失效通知，发送通知
    if should_notify_mirror_fail; then
        send_notify "❌ 所有镜像均失效" "请手动配置代理"
    fi
    echo "❌ 所有镜像均失效"
    touch "$VALID_MIRRORS"
fi

rm -f "$TMP_VALID_MIRRORS"
