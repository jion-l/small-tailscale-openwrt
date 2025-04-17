#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

opkg update

# 检查并安装包
required_packages="libustream-openssl ca-bundle kmod-tun coreutils-timeout"
for package in $required_packages; do
    # 检查包是否已安装
    if ! opkg list-installed | grep -q "$package"; then
        echo "⚠️ 包 $package 未安装，开始安装..."
        opkg install "$package"
        if [ $? -ne 0 ]; then
            echo "❌ 安装 $package 失败，跳过该包"
            continue
        else
            echo "✅ 包 $package 安装成功"
        fi
    else
        echo "✅ 包 $package 已安装，跳过"
    fi
done

# 加载共享库

CONFIG_DIR="/etc/tailscale"
mkdir -p "$CONFIG_DIR"
MIRROR_FILE_URL="https://ghproxy.ch3ng.top/https://github.com/CH3NGYZ/ts-test/raw/main/mirrors.txt"
MIRROR_LIST="$CONFIG_DIR/mirrors.txt"
SCORE_FILE="$CONFIG_DIR/mirror_scores.txt"
VALID_MIRRORS="$CONFIG_DIR/valid_mirrors.txt"
TMP_VALID_MIRRORS="/tmp/valid_mirrors.tmp"

BIN_NAME="tailscaled_linux_amd64"
SUM_NAME="SHA256SUMS.txt"
BIN_PATH="/tmp/$BIN_NAME"
SUM_PATH="/tmp/$SUM_NAME"

rm -f "$TMP_VALID_MIRRORS" "$VALID_MIRRORS"

# 下载函数
# 下载函数
webget() {
    local result=""
    if command -v curl >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && local progress='-s' || local progress='-#'
        [ -z "$4" ] && local redirect='-L' || local redirect=''
        result=$(timeout 30 curl -w %{http_code} -H "User-Agent: Mozilla/5.0 (curl-compatible)" $progress $redirect -ko "$1" "$2")
        [ -n "$(echo "$result" | grep -e ^2)" ] && result="200"
    elif command -v wget >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && local progress='-q' || local progress='--show-progress'
        [ "$4" = "rediroff" ] && local redirect='--max-redirect=0' || local redirect=''
        local certificate='--no-check-certificate'
        timeout 30 wget --header="User-Agent: Mozilla/5.0" $progress $redirect $certificate -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    else
        echo "Error: Neither curl nor wget available"
        return 1
    fi
    [ "$result" = "200" ] && return 0 || return 1
}

# 镜像测试函数（下载并验证tailscaled）
test_mirror() {
    local mirror=$(echo "$1" | sed 's|/*$|/|')
    local url_bin="${mirror}CH3NGYZ/ts-test/releases/latest/download/$BIN_NAME"
    local url_sum="${mirror}CH3NGYZ/ts-test/releases/latest/download/$SUM_NAME"

    echo "测试 $mirror, 最长需要30秒..."

    rm -f "$BIN_PATH" "$SUM_PATH"
    local start=$(date +%s.%N)

    if webget "$BIN_PATH" "$url_bin" "echooff" && webget "$SUM_PATH" "$url_sum" "echooff"; then
        local sha_expected
        sha_expected=$(grep "$BIN_NAME" "$SUM_PATH" | awk '{print $1}')
        sha_actual=$(sha256sum "$BIN_PATH" | awk '{print $1}')
        if [ "$sha_expected" = "$sha_actual" ]; then
            local end=$(date +%s.%N)
            local dl_time=$(awk "BEGIN {printf \"%.2f\", $end - $start}")
            echo "✅ $mirror 下载成功，用时 ${dl_time}s"
            echo "$(date +%s),$mirror,1,$dl_time,-" >> "$SCORE_FILE"
            echo "$dl_time $mirror" >> "$TMP_VALID_MIRRORS"
        else
            echo "❌ $mirror 校验失败"
            echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
        fi
    else
        echo "❌ $mirror 下载失败"
        echo "$(date +%s),$mirror,0,999,0" >> "$SCORE_FILE"
    fi

    rm -f "$BIN_PATH" "$SUM_PATH"
}

# 手动回退逻辑
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
                    [ -s "$TMP_VALID_MIRRORS" ] && sort -n "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
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

# 下载镜像列表
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

# 主流程：测试所有镜像
while read -r mirror; do
    [ -n "$mirror" ] && test_mirror "$mirror"
done < "$MIRROR_LIST"

# 排序并保存最佳镜像
if [ -s "$TMP_VALID_MIRRORS" ]; then
    sort -n "$TMP_VALID_MIRRORS" | awk '{print $2}' > "$VALID_MIRRORS"
    echo "✅ 最佳镜像: $(head -n1 "$VALID_MIRRORS")"
else
    manual_fallback
fi

rm -f "$TMP_VALID_MIRRORS"
