#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"

# 加载配置
[ -f "$CONFIG_DIR/install.conf" ] && . "$CONFIG_DIR/install.conf"

# 参数解析
MODE="local"
AUTO_UPDATE=false
VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --tmp) MODE="tmp"; shift ;;
        --auto-update) AUTO_UPDATE=true; shift ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 执行安装
echo "🚀 开始安装Tailscale..."
"$CONFIG_DIR/fetch_and_install.sh" \
    --mode="$MODE" \
    --version="$VERSION" \
    --mirror-list="$CONFIG_DIR/valid_mirrors.txt"

# 配置服务
echo "🛠️ 初始化服务..."
"$CONFIG_DIR/setup_service.sh" --mode="$MODE"

# 配置定时任务
echo "⏰ 设置定时任务..."
"$CONFIG_DIR/setup_cron.sh" --auto-update="$AUTO_UPDATE"

# 保存配置
cat > "$CONFIG_DIR/install.conf" <<EOF
MODE=$MODE
AUTO_UPDATE=$AUTO_UPDATE
VERSION=$VERSION
TIMESTAMP=$(date +%s)
EOF

echo "🎉 安装完成！"
echo "🔧 管理命令："
echo "   /etc/init.d/tailscale [start|stop|restart]"
echo "   /etc/tailscale/update_ctl.sh [on|off|status]"