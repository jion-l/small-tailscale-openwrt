#!/bin/sh

set -e

# 配置目录
CONFIG_DIR="/etc/tailscale"
BIN_DIR="/usr/local/bin"
mkdir -p "$CONFIG_DIR"

# 写入默认镜像
cat > "$CONFIG_DIR/mirrors.txt" <<'EOF'
https://wget.la/
https://ghproxy.net/
https://mirror.ghproxy.com/
EOF

# 参数解析
MODE="local"
AUTO_UPDATE=false
VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --tmp) MODE="tmp"; shift ;;
        --auto-update) AUTO_UPDATE=true; shift ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        --no-mirror) rm -f "$CONFIG_DIR/mirrors.txt"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 下载安装
echo "正在安装Tailscale..."
chmod +x "$CONFIG_DIR/fetch_and_install.sh"
"$CONFIG_DIR/fetch_and_install.sh" \
    --mode="$MODE" \
    --version="$VERSION" \
    $([ -f "$CONFIG_DIR/mirrors.txt" ] && echo "--mirror-list=$CONFIG_DIR/mirrors.txt")

# 配置服务
cat > /etc/init.d/tailscale <<'EOF'
#!/bin/sh /etc/rc.common
START=99

start() {
    [ -x "/usr/local/bin/tailscaled" ] && exec /usr/local/bin/tailscaled
    [ -x "/tmp/tailscaled" ] && exec /tmp/tailscaled
}

stop() {
    killall tailscaled
}
EOF
chmod +x /etc/init.d/tailscale
/etc/init.d/tailscale enable

# 保存配置
cat > "$CONFIG_DIR/install.conf" <<EOF
MODE=$MODE
AUTO_UPDATE=$AUTO_UPDATE
VERSION=$VERSION
TIMESTAMP=$(date +%s)
EOF

# 设置控制脚本
cat > "$CONFIG_DIR/autoupdate_ctl.sh" <<'EOF'
#!/bin/sh
[ -f "/etc/tailscale/install.conf" ] && . /etc/tailscale/install.conf

case "$1" in
    on|enable)
        touch "$CONFIG_DIR/auto_update_enabled"
        echo "0 3 * * * $CONFIG_DIR/autoupdate.sh" >> /etc/crontabs/root
        /etc/init.d/cron restart
        echo "自动更新已启用"
        ;;
    off|disable)
        rm -f "$CONFIG_DIR/auto_update_enabled"
        sed -i "\|$CONFIG_DIR/autoupdate.sh|d" /etc/crontabs/root
        /etc/init.d/cron restart
        echo "自动更新已禁用"
        ;;
    status)
        [ -f "$CONFIG_DIR/auto_update_enabled" ] && \
            echo "状态: 已启用" || \
            echo "状态: 已禁用"
        ;;
    *)
        echo "用法: $0 [on|off|status]"
        exit 1
        ;;
esac
EOF
chmod +x "$CONFIG_DIR/autoupdate_ctl.sh"

# 初始状态设置
if $AUTO_UPDATE; then
    "$CONFIG_DIR/autoupdate_ctl.sh" on
else
    "$CONFIG_DIR/autoupdate_ctl.sh" off
fi

echo "安装完成！模式: $MODE, 版本: $VERSION"