#!/bin/sh

set -e
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

# 镜像测试函数（同之前）
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

# 主流程
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror"
done < "$MIRROR_LIST"

# 排序并保存有效镜像
if [ -s "$TMP_VALID_MIRRORS" ]; then
    sort -rn "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
    echo "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    # 所有镜像失败，发送通知
    send_notify "MIRROR_FAIL" "镜像全失败" "请检查网络或手动配置代理"
    echo "❌ 所有镜像均失效"
    touch "$VALID_MIRRORS"  # 空文件表示直连备用
fi

rm -f "$TMP_VALID_MIRRORS"
