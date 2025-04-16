#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
[ -f "$CONFIG_DIR/install.conf" ] && . "$CONFIG_DIR/install.conf"

# 下载逻辑
download_with_mirror() {
    local url="https://github.com/CH3NGYZ/ts-test/releases/download/$VERSION/tailscaled_linux_$(uname -m)"
    
    if [ -f "$CONFIG_DIR/mirrors.txt" ]; then
        while read -r mirror; do
            echo "尝试镜像: $mirror"
            if curl -sL "${mirror}${url}" -o /tmp/tailscaled.tmp && [ -s /tmp/tailscaled.tmp ]; then
                mv /tmp/tailscaled.tmp /tmp/tailscaled
                return 0
            fi
        done < "$CONFIG_DIR/mirrors.txt"
    fi
    
    curl -sL "$url" -o /tmp/tailscaled
}

# 安装逻辑
install_file() {
    chmod +x /tmp/tailscaled
    if [ "$MODE" = "local" ]; then
        mkdir -p /usr/local/bin
        mv /tmp/tailscaled /usr/local/bin/
        ln -sf /usr/local/bin/tailscaled /usr/local/bin/tailscale
    else
        mv /tmp/tailscaled /tmp/
        ln -sf /tmp/tailscaled /tmp/tailscale
    fi
    echo "$VERSION" > "$CONFIG_DIR/current_version"
}

download_with_mirror
install_file