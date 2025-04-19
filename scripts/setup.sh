#!/bin/sh

set -e
. /etc/tailscale/tools.sh || { log_error "❌  加载 tools.sh 失败"; exit 1; }
log_info "加载公共函数..."

log_info "加载配置文件..."
safe_source "$INST_CONF" || log_warn "⚠️  INST_CONF 未找到或无效，使用默认配置"

get_arch() {
    arch_=$(uname -m)
    case "$arch_" in
        i386) arch=386 ;;
        x86_64) arch=amd64 ;;
        armv7l) arch=arm ;;
        aarch64|armv8l) arch=arm64 ;;
        mips) 
            arch=mips
            endianness=$(echo -n I | hexdump -o | awk '{ print (substr($2,6,1)=="1") ? "le" : "be"; exit }')
            ;;
        *) 
            echo "❌  不支持的架构: $arch_"
            exit 1
            ;;
    esac
    [ -n "$endianness" ] && arch="${arch}${endianness}"
    echo "$arch"
}

# 默认值
MODE=""
AUTO_UPDATE=""
VERSION="latest"
ARCH=$(get_arch)
HOST_NAME=$(uci show system.@system[0].hostname | awk -F"'" '{print $2}')

has_args=false  # 🔧  新增：标记是否传入了参数

# 若有参数, 接受 --tmp为使用内存模式, --auto-update为自动更新
while [ $# -gt 0 ]; do
    has_args=true  # 🔧  有参数，关闭交互模式
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
    log_info "📮 请选择安装模式："
    log_info "     1). 本地安装 (默认) 🏠"
    log_info "     2). 内存安装 (临时) 💻"
    log_info "     3). 退出           ⛔"
    log_info "⏳  请输入选项 [1/2/3]: " 1
    read mode_input

    case "$mode_input" in
        3) log_error "❌  已取消安装"; exit 1 ;;
        2) MODE="tmp" ;;
        *) MODE="local" ;;
    esac

    log_info
    log_info "🔄  是否启用自动更新？"
    log_info "      1). 是 (默认) ✅"
    log_info "      2). 否        ❌"
    log_info "      3). 退出      ⛔"
    log_info "⏳  请输入选项 [1/2/3]: " 1
    read update_input

    case "$update_input" in
        3) log_error "⛔  已取消安装"; exit 1 ;;
        2) AUTO_UPDATE=false ;;
        *) AUTO_UPDATE=true ;;
    esac

    # 🧩 拉取 release tag 列表
    HTTP_CODE=$(curl -s -w "%{http_code}" -o response.json "https://api.github.com/repos/ch3ngyz/small-tailscale-openwrt/releases")

    if [ "$HTTP_CODE" -ne 200 ]; then
        log_error "❌  GitHub API 请求失败，状态码: $HTTP_CODE"
        log_info "🔧  无法获取可用版本号，将跳过版本校验"
        VERSION="latest"
    else
        TAGS_TMP="/tmp/.tags.$$"
        grep '"tag_name":' response.json | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' > "$TAGS_TMP"
        rm -f response.json

        if [ ! -s "$TAGS_TMP" ]; then
            log_error "❌  未找到任何版本标签"
            VERSION="latest"
        else
            log_info "🔧  可用版本列表："
            i=1
            while read -r tag; do
                log_info "  [$i] $tag"
                eval "TAG_$i=\"$tag\""
                i=$((i + 1))
            done < "$TAGS_TMP"
            total=$((i - 1))
            log_info "⏳  请输入序号选择版本 (留空使用 latest): " 1
            read index
            index=$(echo "$index" | xargs)

            if [ -z "$index" ]; then
                VERSION="latest"
            elif echo "$index" | grep -qE '^[0-9]+$' && [ "$index" -ge 1 ] && [ "$index" -le "$total" ]; then
                eval "VERSION=\$TAG_$index"
                log_info "✅  使用指定版本: $VERSION"
            else
                log_error "❌  无效的选择：$index"
                exit 1
            fi

            rm -f "$TAGS_TMP"
        fi
    fi
fi


# 兜底
MODE=${MODE:-local}
AUTO_UPDATE=${AUTO_UPDATE:-false}
VERSION=${VERSION:-latest}

cat > "$INST_CONF" <<EOF
# 安装配置记录
MODE=$MODE
AUTO_UPDATE=$AUTO_UPDATE
VERSION=$VERSION
ARCH=$ARCH
HOST_NAME=$HOST_NAME
TIMESTAMP=$(date +%s)
EOF

# 显示当前配置
echo
log_info "🎯  当前安装配置："
log_info "🎯  模式: $MODE"
log_info "🎯  更新: $AUTO_UPDATE"
log_info "🎯  版本: $VERSION"
log_info "🎯  架构: $ARCH"
log_info "🎯  昵称: $HOST_NAME"
echo

# 停止服务之前，检查服务文件是否存在
if [ -f /etc/init.d/tailscale ]; then
    log_info "🔴  停止 tailscaled 服务..."
    /etc/init.d/tailscale stop 2>/dev/null || log_warn "⚠️  停止 tailscaled 服务失败，继续清理残留文件"
else
    log_warn "⚠️  未找到 tailscale 服务文件，跳过停止服务步骤"
fi

# 清理残留文件
log_info "🧹  清理残留文件..."
if [ "$MODE" = "local" ]; then
    log_info "🗑️  删除本地安装的残留文件..."
    rm -f /usr/local/bin/tailscale
    rm -f /usr/local/bin/tailscaled
fi

if [ "$MODE" = "tmp" ]; then
    log_info "🗑️  删除/tmp中的残留文件..."
    rm -f /tmp/tailscale
    rm -f /tmp/tailscaled
fi

# 安装开始
log_info "🚀  开始安装 Tailscale..."
"$CONFIG_DIR/fetch_and_install.sh" \
    --mode="$MODE" \
    --version="$VERSION" \
    --mirror-list="$VALID_MIRRORS"

# 初始化服务
log_info "🛠️  初始化服务..."
"$CONFIG_DIR/setup_service.sh" --mode="$MODE"

# 设置定时任务
log_info "⏰  设置定时任务..."
"$CONFIG_DIR/setup_cron.sh" --auto-update="$AUTO_UPDATE"
