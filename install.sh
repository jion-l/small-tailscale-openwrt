#!/bin/sh
set -e

CONFIG_DIR="/etc/tailscale"
MIRROR_LIST_URL="https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/mirrors.txt"
SCRIPTS_TGZ_URL="https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/tailscale-openwrt-scripts.tar.gz"
EXPECTED_CHECKSUM="预先计算的tar.gz包的SHA256校验和"

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
        result=$(curl -w %{http_code} --connect-timeout 10 $progress $redirect -ko "$1" "$2")
        [ -n "$(echo "$result" | grep -e ^2)" ] && result="200"
    else
        if command -v wget >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && local progress='-q' || local progress='--show-progress'
            [ "$4" = "rediroff" ] && local redirect='--max-redirect=0' || local redirect=''
            local certificate='--no-check-certificate'
            local timeout='--timeout=10'
            wget $progress $redirect $certificate $timeout -O "$1" "$2"
            [ $? -eq 0 ] && result="200"
        else
            echo "Error: Neither curl nor wget available"
            return 1
        fi
    fi
    
    [ "$result" = "200" ] && return 0 || return 1
}


mirror_fetch "$MIRROR_LIST_URL" "/tmp/mirrors.txt" || {
    echo "❌ 下载镜像列表失败"
    exit 1
}

mirror_fetch "$SCRIPTS_TGZ_URL" "/tmp/tailscale-openwrt-scripts.tar.gz" || {
    echo "❌ 下载脚本包失败"
    exit 1
}


# 解压脚本
echo "📦 解压脚本包..."
tar -xzf "/tmp/tailscale-openwrt-scripts.tar.gz" -C "$CONFIG_DIR"
mv "/tmp/mirrors.txt" "$CONFIG_DIR/mirrors.txt"

# 设置权限
chmod +x "$CONFIG_DIR"/*.sh

# 初始化通知配置
cat > "$CONFIG_DIR/notify.conf" <<'EOF'
# 通知开关 (1=启用 0=禁用)
NOTIFY_UPDATE=1
NOTIFY_MIRROR_FAIL=1
NOTIFY_EMERGENCY=1

# Server酱SendKey
SERVERCHAN_KEY=""
EOF

echo "✅ 基础安装完成！请执行："
echo "   /etc/tailscale/setup.sh [options]"
