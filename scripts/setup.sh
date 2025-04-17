#!/bin/sh

set -e

echo "加载公共函数..."
. /etc/tailscale/common.sh || { echo "❌ 加载 common.sh 失败"; exit 1; }

echo "加载配置文件..."
safe_source "$INST_CONF" || echo "⚠️ INST_CONF 未找到或无效，使用默认配置"

# 默认值
MODE=""
AUTO_UPDATE=""
VERSION="latest"

# 若无参数，进入交互模式
if [ $# -eq 0 ]; then
    echo
    echo "请选择安装模式："
    echo "  1) 本地安装（默认）"
    echo "  2) 内存安装"
    echo "  3) 退出"
    printf "请输入选项 [1/2/3]: "
    read mode_input

    case "$mode_input" in
        3) echo "❌ 已取消安装"; exit 1 ;;
        2) MODE="tmp" ;;
        *) MODE="local" ;;
    esac

    echo
    echo "是否启用自动更新？"
    echo "  1) 是（默认）"
    echo "  2) 否"
    echo "  3) 退出"
    printf "请输入选项 [1/2/3]: "
    read update_input

    case "$update_input" in
        3) echo "❌ 已取消安装"; exit 1 ;;
        2) AUTO_UPDATE=false ;;
        *) AUTO_UPDATE=true ;;
    esac

    echo
    printf "是否安装最新版本？(回车默认最新，或输入具体版本号): "
    read version_input
    VERSION="$(echo "$version_input" | xargs)"  # 去除空格
    [ -z "$VERSION" ] && VERSION="latest"
fi

# 兜底
MODE=${MODE:-local}
AUTO_UPDATE=${AUTO_UPDATE:-false}
VERSION=${VERSION:-latest}

# 安装开始
echo "🚀 开始安装 Tailscale..."
"$CONFIG_DIR/fetch_and_install.sh" \
    --mode="$MODE" \
    --version="$VERSION" \
    --mirror-list="$CONFIG_DIR/valid_mirrors.txt"

# 初始化服务
echo "🛠️ 初始化服务..."
"$CONFIG_DIR/setup_service.sh" --mode="$MODE"

# 设置定时任务
echo "⏰ 设置定时任务..."
"$CONFIG_DIR/setup_cron.sh" --auto-update="$AUTO_UPDATE"

# 保存配置
mkdir -p "$(dirname "$INST_CONF")"
cat > "$INST_CONF" <<EOF
# 安装配置记录
MODE=$MODE
AUTO_UPDATE=$AUTO_UPDATE
VERSION=$VERSION
TIMESTAMP=$(date +%s)
EOF

echo
echo "🎉 \033[1;32m安装完成！\033[0m"
echo "🔧 启动命令："
echo "   \033[1;34mtailscale up\033[0m"

echo
echo "🔧 管理更新："
echo "   \033[1;34m/etc/tailscale/update_ctl.sh [on|off|status]\033[0m"
