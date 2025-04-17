#!/bin/sh

set -e
. /etc/tailscale/common.sh || { log_error "❌ 加载 common.sh 失败"; exit 1; }
log_info "加载公共函数..."

log_info "加载配置文件..."
safe_source "$INST_CONF" || log_warn "⚠️ INST_CONF 未找到或无效，使用默认配置"

# 默认值
MODE=""
AUTO_UPDATE=""
VERSION="latest"
has_args=false  # 🔧 新增：标记是否传入了参数

# 若有参数, 接受 --tmp为使用内存模式, --auto-update为自动更新
while [ $# -gt 0 ]; do
    has_args=true  # 🔧 有参数，关闭交互模式
    case "$1" in
        --tmp) MODE="tmp"; shift ;;
        --auto-update) AUTO_UPDATE=true; shift ;;
        --version=*) VERSION="${1#*=}"; shift ;;
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

# 若无参数，进入交互模式
if [ "$has_args" = false ]; then
    log_info
    log_info "请选择安装模式："
    log_info "  1) 本地安装（默认）"
    log_info "  2) 内存安装"
    log_info "  3) 退出"
    log_info "请输入选项 [1/2/3]: "
    read mode_input

    case "$mode_input" in
        3) log_error "❌ 已取消安装"; exit 1 ;;
        2) MODE="tmp" ;;
        *) MODE="local" ;;
    esac

    log_info
    log_info "是否启用自动更新？"
    log_info "  1) 是（默认）"
    log_info "  2) 否"
    log_info "  3) 退出"
    log_info "请输入选项 [1/2/3]: "
    read update_input

    case "$update_input" in
        3) log_error "❌ 已取消安装"; exit 1 ;;
        2) AUTO_UPDATE=false ;;
        *) AUTO_UPDATE=true ;;
    esac

    log_info
    log_info "请输入版本号 (留空使用 latest): "
    read version_input
    version_input="$(echo "$version_input" | xargs)"  # 去空格

    if [[ -z "$version_input" ]]; then
        VERSION="latest"
    elif [[ "$version_input" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        VERSION="v${version_input#v}"  # 确保是 v 开头
    else
        log_error "❌ 无效的版本号格式: $version_input"
        exit 1
    fi
 
    if [[ "$VERSION" != "latest" ]]; then
        log_info "🔧 使用指定版本: $VERSION"

        # 如果是交互模式输入了版本号
        log_info "🔍 检查版本号是否存在于 GitHub Release 中..."

        HTTP_CODE=$(curl -s -w "%{http_code}" -o response.json "https://api.github.com/repos/ch3ngyz/ts-test/releases")

        if [ "$HTTP_CODE" -ne 200 ]; then
            log_error "❌ GitHub API 请求失败，状态码: $HTTP_CODE"
            log_info "🔧 跳过版本号检查，继续安装"
        else
            TAGS=$(jq -r '.[].tag_name' response.json)

            TAG_CHECK=$(echo "$TAGS" | grep -w "$VERSION" || true)  # <--- 防止 grep 没找到时退出

            rm -f response.json

            if [ -z "$TAG_CHECK" ]; then
                log_error "❌ 版本 ${VERSION} 不存在于 GitHub Release 中，请检查输入"
                log_info "🔧 可用的版本列表如下："
                echo "$TAGS" | awk '{ print "  " $1 }' | while read line; do
                    log_info "$line"
                done
                exit 1
            fi
        fi
    fi
fi

# 兜底
MODE=${MODE:-local}
AUTO_UPDATE=${AUTO_UPDATE:-false}
VERSION=${VERSION:-latest}

# 显示当前配置
log_info
log_info "🎯 当前安装配置："
log_info "安装模式: $MODE"
log_info "启用自动更新: $AUTO_UPDATE"
log_info "版本: $VERSION"
log_info

# 停止服务之前，检查服务文件是否存在
if [ -f /etc/init.d/tailscale ]; then
    log_info "🔴 停止 tailscaled 服务..."
    /etc/init.d/tailscale stop 2>/dev/null || log_warn "⚠️ 停止 tailscaled 服务失败，继续清理残留文件"
else
    log_warn "⚠️ 未找到 tailscale 服务文件，跳过停止服务步骤"
fi

# 清理残留文件
log_info "🧹 清理残留文件..."
if [ "$MODE" = "local" ]; then
    log_info "🗑️ 删除本地安装的残留文件..."
    rm -f /usr/local/bin/tailscale
    rm -f /usr/local/bin/tailscaled
fi

if [ "$MODE" = "tmp" ]; then
    log_info "🗑️ 删除/tmp中的残留文件..."
    rm -f /tmp/tailscale
    rm -f /tmp/tailscaled
fi

# 安装开始
log_info "🚀 开始安装 Tailscale..."
"$CONFIG_DIR/fetch_and_install.sh" \
    --mode="$MODE" \
    --version="$VERSION" \
    --mirror-list="$CONFIG_DIR/valid_mirrors.txt"

# 初始化服务
log_info "🛠️ 初始化服务..."
"$CONFIG_DIR/setup_service.sh" --mode="$MODE"

# 设置定时任务
log_info "⏰ 设置定时任务..."
"$CONFIG_DIR/setup_cron.sh" --auto-update="$AUTO_UPDATE"

# 保存配置
log_info "💾 保存配置文件..."
mkdir -p "$(dirname "$INST_CONF")"
cat > "$INST_CONF" <<EOF
# 安装配置记录
MODE=$MODE
AUTO_UPDATE=$AUTO_UPDATE
VERSION=$VERSION
TIMESTAMP=$(date +%s)
EOF

# 安装完成
log_info
log_info "🎉 安装完成！"
log_info "🔧 启动命令："
log_info "   tailscale up"
log_info
log_info "🔧 管理自动更新："
log_info "   /etc/tailscale/update_ctl.sh"
log_info
log_info "🔧 查看当前最新版本："
log_info "   /etc/tailscale/fetch_and_install.sh --dry-run"
log_info
log_info "🔧 自动排序可用镜像代理："
log_info "   /etc/tailscale/test_mirrors.sh"
log_info
log_info "🔧 管理server酱推送："
log_info "   /etc/tailscale/notify_ctl.sh"
log_info
log_info "🔧 切换安装模式(重新安装)："
log_info "   /etc/tailscale/setup.sh"
log_info
log_info "🔧 拉取最新镜像地址："
log_info "   curl -o /tmp/pretest_mirrors.sh -L https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/pretest_mirrors.sh && sh /tmp/pretest_mirrors.sh"
log_info "   或"
log_info "   wget -O /tmp/pretest_mirrors.sh https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/pretest_mirrors.sh && sh /tmp/pretest_mirrors.sh"
