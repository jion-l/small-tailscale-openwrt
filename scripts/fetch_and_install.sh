#!/bin/sh

set -e
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh && safe_source "$INST_CONF"


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

get_checksum() {
    local sums_file=$1
    local target_name=$2
    grep " $target_name" "$sums_file" | awk '{print $1}'
}

# 下载文件
download_file() {
    local url=$1
    local output=$2
    local mirror_list=${3:-}
    local checksum=${4:-}

    if [ -f "$mirror_list" ]; then
        while read -r mirror; do
            mirror=$(echo "$mirror" | sed 's|/*$|/|')
            log_info "⬇️ 下载: ${mirror}${url}"
            if webget "$output" "${mirror}${url}" "echooff"; then
                [ -n "$checksum" ] && verify_checksum "$output" "$checksum" || return 0
                return 0
            fi
        done < "$mirror_list"
    fi

    log_info "⬇️ 尝试直接连接..."
    if webget "$output" "$url" "echooff"; then
        [ -n "$checksum" ] && verify_checksum "$output" "$checksum"
        return 0
    else
        return 1
    fi
}

verify_checksum() {
    local file=$1
    local expected=$2

    local actual=""
    if [ ${#expected} -eq 64 ]; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif [ ${#expected} -eq 32 ]; then
        actual=$(md5sum "$file" | awk '{print $1}')
    else
        log_warn "⚠️ 未知校验长度，跳过校验"
        return 0
    fi

    if [ "$expected" = "$actual" ]; then
        log_info "✅ 校验通过"
        return 0
    else
        log_error "❌ 校验失败"
        return 1
    fi
}

# 主安装流程
install_tailscale() {
    local version=$1
    local mode=$2
    local mirror_list=$3

    local arch=$(get_arch)
    local pkg_name="tailscaled_linux_$arch"
    local download_url="CH3NGYZ/ts-test/releases/download/$version/$pkg_name"
    local tmp_file="/tmp/tailscaled.$$"

    log_info "⬇️ 准备校验文件..."
    sha_file="/tmp/SHA256SUMS.$$"
    md5_file="/tmp/MD5SUMS.$$"
    pkg_name="tailscaled_linux_$arch"
    download_base="CH3NGYZ/ts-test/releases/download/$version/"

    # 下载校验文件
    download_file "${download_base}SHA256SUMS.txt" "$sha_file" "$mirror_list" || log_warn "⚠️ 无法获取 SHA256 校验文件"
    download_file "${download_base}MD5SUMS.txt" "$md5_file" "$mirror_list" || log_warn "⚠️ 无法获取 MD5 校验文件"

    sha256=""
    md5=""
    [ -s "$sha_file" ] && sha256=$(get_checksum "$sha_file" "$pkg_name")
    [ -s "$md5_file" ] && md5=$(get_checksum "$md5_file" "$pkg_name")
    echo $md5
    echo $sha256

    # 下载主程序并校验
    log_info "⬇️ 正在下载 Tailscale $version ($arch)..."
    if ! download_file "$download_base$pkg_name" "$tmp_file" "$mirror_list" "$sha256"; then
        log_warn "⚠️ SHA256 校验失败，尝试使用 MD5..."
        if ! download_file "$download_base$pkg_name" "$tmp_file" "$mirror_list" "$md5"; then
            log_error "❌ 校验失败，安装中止"
            rm -f "$tmp_file"
            exit 1
        fi
    fi


    # 安装
    chmod +x "$tmp_file"
    if [ "$mode" = "local" ]; then
        mkdir -p /usr/local/bin
        mv "$tmp_file" /usr/local/bin/tailscaled
        ln -sf /usr/local/bin/tailscaled /usr/local/bin/tailscale
        ln -sf /usr/local/bin/tailscaled /usr/bin/tailscaled
        ln -sf /usr/local/bin/tailscaled /usr/bin/tailscale
        log_info "✅ 安装到 /usr/local/bin/"
    else
        mv "$tmp_file" /tmp/tailscaled
        ln -sf /tmp/tailscaled /usr/bin/tailscaled
        ln -sf /tmp/tailscaled /usr/bin/tailscale
        log_info "✅ 安装到 /tmp (内存模式)"
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
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

# 处理版本
if [ "$VERSION" = "latest" ]; then
    VERSION=$(get_latest_version) || {
        log_error "❌ 获取最新版本失败"
        exit 1
    }
fi

# 干跑模式（只输出版本号）
if [ "$DRY_RUN" = "true" ]; then
    echo "$VERSION"
    exit 0
fi

# 执行安装
install_tailscale "$VERSION" "$MODE" "$MIRROR_LIST"
