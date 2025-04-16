#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
[ -f "$CONFIG_DIR/install.conf" ] && . "$CONFIG_DIR/install.conf"

# 架构映射
get_arch() {
    case $(uname -m) in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "arm" ;;
        *) echo "$(uname -m)" ;;
    esac
}

# 获取最新版本
get_latest_version() {
    local api_url="https://api.github.com/repos/CH3NGYZ/ts-test/releases/latest"
    local version=$(curl -m 10 -fsSL "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$version"
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    local mirror_list=${3:-}

    if [ -f "$mirror_list" ]; then
        while read -r mirror; do
            mirror=$(echo "$mirror" | sed 's|/*$|/|')
            echo "尝试镜像: $mirror"
            if curl -m 20 -fsSL "${mirror}${url}" -o "$output"; then
                return 0
            fi
        done < "$mirror_list"
    fi

    echo "尝试直连GitHub..."
    curl -m 30 -fsSL "$url" -o "$output"
}

# 主安装流程
install_tailscale() {
    local version=$1
    local mode=$2
    local mirror_list=$3

    local arch=$(get_arch)
    local pkg_name="tailscaled_linux_$arch"
    local download_url="https://github.com/CH3NGYZ/ts-test/releases/download/$version/$pkg_name"
    local tmp_file="/tmp/tailscaled.$$"

    # 下载
    echo "⬇️ 下载Tailscale $version ($arch)..."
    download_file "$download_url" "$tmp_file" "$mirror_list" || {
        echo "❌ 下载失败"
        rm -f "$tmp_file"
        exit 1
    }

    # 安装
    chmod +x "$tmp_file"
    if [ "$mode" = "local" ]; then
        mkdir -p /usr/local/bin
        mv "$tmp_file" /usr/local/bin/tailscaled
        ln -sf /usr/local/bin/tailscaled /usr/local/bin/tailscale
        echo "✅ 已安装到 /usr/local/bin/"
    else
        mv "$tmp_file" /tmp/tailscaled
        ln -sf /tmp/tailscaled /tmp/tailscale
        echo "✅ 已安装到 /tmp (内存模式)"
    fi

    echo "$version" > "$CONFIG_DIR/current_version"
}

# 参数解析
MODE="local"
VERSION="latest"
MIRROR_LIST=""
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --mode=*) MODE="${1#*=}"; shift ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --mirror-list=*) MIRROR_LIST="${1#*=}"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 处理版本
if [ "$VERSION" = "latest" ]; then
    VERSION=$(get_latest_version) || {
        echo "❌ 获取最新版本失败"
        exit 1
    }
    echo "最新版本: $VERSION"
fi

# 干跑模式
if [ "$DRY_RUN" = "true" ]; then
    echo "$VERSION"
    exit 0
fi

# 执行安装
install_tailscale "$VERSION" "$MODE" "$MIRROR_LIST"