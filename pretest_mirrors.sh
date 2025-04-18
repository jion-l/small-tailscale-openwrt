#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh
TIME_OUT=30

# 加载共享库
mkdir -p "$CONFIG_DIR"
MIRROR_FILE_URL="https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/small-tailscale-openwrt/main/mirrors.txt"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
TMP_VALID_MIRRORS="/tmp/valid_mirrors.tmp"

BIN_NAME="tailscaled_linux_amd64"
SUM_NAME="SHA256SUMS.txt"
BIN_PATH="/tmp/$BIN_NAME"
SUM_PATH="/tmp/$SUM_NAME"

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

log_info() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    [ $# -eq 2 ] || echo
}

log_warn() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    [ $# -eq 2 ] || echo
}

log_error() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    [ $# -eq 2 ] || echo
}

# 下载函数
webget() {
    local result=""
    if command -v curl >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && local progress='-s' || local progress='-#'
        [ -z "$4" ] && local redirect='-L' || local redirect=''
        result=$(timeout $TIME_OUT curl -w %{http_code} -H "User-Agent: Mozilla/5.0 (curl-compatible)" $progress $redirect -ko "$1" "$2")
        [ -n "$(echo "$result" | grep -e ^2)" ] && result="200"
    elif command -v wget >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && local progress='-q' || local progress='--show-progress'
        [ "$4" = "rediroff" ] && local redirect='--max-redirect=0' || local redirect=''
        local certificate='--no-check-certificate'
        timeout $TIME_OUT wget --header="User-Agent: Mozilla/5.0" $progress $redirect $certificate -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    else
        log_error "❌ 错误：curl 和 wget 都不可用"
        return 1
    fi
    [ "$result" = "200" ] && return 0 || return 1
}

# 镜像测试函数（下载并验证 tailscaled）
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')
    local url_bin="${mirror}CH3NGYZ/small-tailscale-openwrt/releases/latest/download/$BIN_NAME"
    local url_sum="${mirror}CH3NGYZ/small-tailscale-openwrt/releases/latest/download/$SUM_NAME"

    log_info "⏳ 测试 $mirror，最长需要 $TIME_OUT 秒..."

    rm -f "$BIN_PATH" "$SUM_PATH"
    local start=$(date +%s.%N)

    if webget "$BIN_PATH" "$url_bin" "echooff" && webget "$SUM_PATH" "$url_sum" "echooff"; then
        local sha_expected
        sha_expected=$(grep "$BIN_NAME" "$SUM_PATH" | awk '{print $1}')
        sha_actual=$(sha256sum "$BIN_PATH" | awk '{print $1}')
        if [ "$sha_expected" = "$sha_actual" ]; then
            local end=$(date +%s.%N)
            local dl_time=$(awk "BEGIN {printf \"%.2f\", $end - $start}")
            log_info "✅ $mirror 下载成功，用时 ${dl_time}s"
            log_info "$(date +%s),$mirror,1,$dl_time,-" >> "$SCORE_FILE"
            echo "$dl_time $mirror" >> "$TMP_VALID_MIRRORS"
        else
            log_warn "❌ $mirror 校验失败"
            log_info "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
        fi
    else
        log_warn "❌ $mirror 下载失败"
        log_info "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
    fi

    rm -f "$BIN_PATH" "$SUM_PATH"
}

# 手动回退逻辑
manual_fallback() {
    log_info "🧩 手动选择镜像源："
    log_info "1) ✍️ 手动输入镜像  2) 🌐 使用直连  3) ❌ 退出"
    while :; do
        log_info "请选择: " 1
        read choice
        case $choice in
            1)
                log_info "⏳ 输入镜像URL (如 https://mirror.example.com/https://github.com/): " 1
                read  mirror
                mirror=$(echo "$mirror" | sed 's|/*$|/|')
                if echo "$mirror" | grep -qE '^https?://'; then
                    echo "$mirror" >> "$MIRROR_LIST"
                    test_mirror "$mirror"
                    [ -s "$TMP_VALID_MIRRORS" ] && sort -n "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
                    return 0
                else
                    log_warn "⚠️ 地址必须以 http:// 或 https:// 开头"
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

# 下载镜像列表
log_info "🛠️ 正在下载镜像列表，请耐心等待..."
if webget "$MIRROR_LIST" "$MIRROR_FILE_URL" "echooff"; then
    log_info "✅ 已更新镜像列表"
else
    log_warn "⚠️ 无法下载镜像列表，尝试使用旧版本（如果存在）"
    [ -s "$MIRROR_LIST" ] || {
        log_error "❌ 没有可用镜像列表，且下载失败"
        manual_fallback
        exit 1
    }
fi

# 主流程：测试所有镜像
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror"
done < "$MIRROR_LIST"

# 排序并保存最佳镜像
if [ -s "$TMP_VALID_MIRRORS" ]; then
    sort -n "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
    log_info "🏆 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    manual_fallback
fi

rm -f "$TMP_VALID_MIRRORS"

# 安装主程序
log_info "📦 正在启动安装脚本..."
curl -sSL https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/small-tailscale-openwrt/main/install.sh | sh
