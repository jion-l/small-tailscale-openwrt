#!/bin/sh
set -e

CONFIG_DIR="/etc/tailscale"
mkdir -p "$CONFIG_DIR"
SCRIPTS_TGZ_URL="CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/tailscale-openwrt-scripts.tar.gz"
SCRIPTS_PATH="/tmp/tailscale-openwrt-scripts.tar.gz"

# 预先计算的校验和
EXPECTED_CHECKSUM_SHA256="cd64f74699a6dc6ce0d3a6f54825a9504c8357e7fd96f3bfb80ff40737802885"
EXPECTED_CHECKSUM_MD5="9302a11f7c975a016df847ff2354508d"
TIME_OUT=30
log_info() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    [ $# -eq 2 ] || echo
}

log_warn() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    [ $# -eq 2 ] || echo
}

log_error() {
    echo -n "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    [ $# -eq 2 ] || echo
}

log_info "📦  开始检查并安装必要组件..."
log_info "🔄  正在更新 opkg 源..."
if ! opkg update >/dev/null 2>&1; then
    log_error "❌  opkg update 失败，请检查网络连接或源配置"
    exit 1
fi

required_packages="libustream-openssl ca-bundle kmod-tun coreutils-timeout coreutils-nohup"
for package in $required_packages; do
    if ! opkg list-installed | grep -q "$package"; then
        log_info "⚠️  包 $package 未安装，开始安装..."
        if opkg install "$package" >/dev/null 2>&1; then
            log_info "✅  包 $package 安装成功"
        else
            if [ "$package" = "coreutils-timeout" ]; then
                log_warn "⚠️  安装 $package 失败，尝试安装 coreutils 替代..."
                if opkg install coreutils >/dev/null 2>&1; then
                    log_info "✅  coreutils 安装成功，可能已包含 timeout 命令"
                    continue
                fi
            fi
            if [ "$package" = "coreutils-nohup" ]; then
                log_warn "⚠️  安装 $package 失败，尝试安装 coreutils 替代..."
                if opkg install coreutils >/dev/null 2>&1; then
                    log_info "✅  coreutils 安装成功，可能已包含 nohup 命令"
                    continue
                fi
            fi
            log_error "❌  安装 $package 失败，无法继续，请手动安装此包"
            exit 1
        fi
    else
        log_info "✅  包 $package 已安装，跳过"
    fi
done

# ➕ 添加 timeout 命令最终检查
if ! command -v timeout >/dev/null 2>&1; then
    log_error "❌  未检测到 timeout 命令，尽管已尝试安装，脚本退出。"
    exit 1
else
    log_info "✅  timeout 命令已可用"
fi

# ➕ 添加 timeout 命令最终检查
if ! command -v nohup >/dev/null 2>&1; then
    log_error "❌  未检测到 nohup 命令，尽管已尝试安装，脚本退出。"
    exit 1
else
    log_info "✅  nohup 命令已可用"
fi


# 校验函数, 接收三个参数：文件路径、校验类型（sha256/md5）、预期值
verify_checksum() {
    local file=$1
    local type=$2
    local expected=$3
    local actual=""

    case "$type" in
        sha256)
            if command -v sha256sum >/dev/null 2>&1; then
                actual=$(sha256sum "$file" | awk '{print $1}')
            elif command -v openssl >/dev/null 2>&1; then
                actual=$(openssl dgst -sha256 "$file" | awk '{print $2}')
            else
                log_error "❌  系统缺少 sha256sum 或 openssl, 无法校验文件"
                return 1
            fi
            ;;
        md5)
            if command -v md5sum >/dev/null 2>&1; then
                actual=$(md5sum "$file" | awk '{print $1}')
            elif command -v openssl >/dev/null 2>&1; then
                actual=$(openssl dgst -md5 "$file" | awk '{print $2}')
            else
                log_error "❌  系统缺少 md5sum 或 openssl, 无法校验文件"
                return 1
            fi
            ;;
        *)
            log_error "❌  校验类型无效: $type"
            return 1
            ;;
    esac

    # 校验结果对比
    if [ "$actual" != "$expected" ]; then
        log_error "❌  校验失败！预期: $expected, 实际: $actual"
        return 1
    fi

    log_info "✅  校验通过"
    return 0
}

# 下载文件的函数
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
        # 修正 curl 的参数：-o 用于指定输出文件
        result=$(timeout "$TIME_OUT" curl -w "%{http_code}" -H "User-Agent: Mozilla/5.0 (curl-compatible)" $progress $redirect -o "$1" "$2")
        # 判断返回的 HTTP 状态码是否为 2xx
        if [[ "$result" =~ ^2 ]]; then
            result="200"
        else
            result="non-200"
        fi
    else
        if command -v wget >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && local progress='-q' || local progress='--show-progress'
            [ "$4" = "rediroff" ] && local redirect='--max-redirect=0' || local redirect=''
            local certificate='--no-check-certificate'
            timeout "$TIME_OUT" wget --header="User-Agent: Mozilla/5.0" $progress $redirect $certificate -O "$1" "$2"
            if [ $? -eq 0 ]; then
                result="200"
            else
                result="non-200"
            fi
        else
            echo "Error: Neither curl nor wget available"
            return 1
        fi
    fi

    [ "$result" = "200" ] && return 0 || return 1
}

# # 使用有效镜像代理进行下载
# mirror_fetch() {
#     local real_url=$1
#     local output=$2
#     local mirror_list_file="$CONFIG_DIR/valid_mirrors.txt"

#     if [ -f "$mirror_list_file" ]; then
#         while read -r mirror; do
#             mirror=$(echo "$mirror" | sed 's|/*$|/|')  # 去掉结尾斜杠
#             full_url="${mirror}${real_url}"
#             log_info "🔗  尝试镜像: $full_url"
#             if webget "$output" "$full_url" "echooff"; then
#                 return 0
#             fi
#         done < "$mirror_list_file"
#     fi

#     # 如果所有代理都失败, 尝试直接下载
#     log_info "🔗  尝试直连: $real_url"
#     webget "$output" "$real_url" "echooff"
# }

# success=0

# # 检查镜像并下载
# if [ -f "$CONFIG_DIR/valid_mirrors.txt" ]; then
#     while read -r mirror; do
#         mirror=$(echo "$mirror" | sed 's|/*$|/|')
#         full_url="${mirror}${SCRIPTS_TGZ_URL}"
#         log_info "🔗  尝试镜像: $full_url"

#         if webget "$SCRIPTS_PATH" "$full_url" "echooff"; then
#             if verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256"; then
#                 success=1
#                 break
#             else
#                 log_info "⚠️  SHA256校验失败, 尝试下一个镜像"
#             fi
#             if verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"; then
#                 success=1
#                 break
#             else
#                 log_info "⚠️  MD5校验失败, 尝试下一个镜像"
#             fi
#         fi
#     done < "$CONFIG_DIR/valid_mirrors.txt"
# fi

# # 所有镜像失败后尝试直连
# if [ "$success" -ne 1 ]; then
#     log_info "🔗  尝试直连: $SCRIPTS_TGZ_URL"
#     if webget "$SCRIPTS_PATH" "$SCRIPTS_TGZ_URL" "echooff" && \
#        verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256"; then
#         success=1
#     fi
#     if [ "$success" -ne 1 ]; then
#         if webget "$SCRIPTS_PATH" "$SCRIPTS_TGZ_URL" "echooff" && \
#            verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"; then
#             success=1
#         fi
#     fi
# fi


# 使用固定代理
proxy_url="https://ghproxy.ch3ng.top/https://github.com/${SCRIPTS_TGZ_URL}"
success=0
log_info "🔗  使用固定代理下载: $proxy_url"
if webget "$SCRIPTS_PATH" "$proxy_url" "echooff" && \
   (verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256" || \
    verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"); then
    success=1
else
    # 尝试直连
    log_info "🔗  代理失效, 尝试直连: https://github.com/${SCRIPTS_TGZ_URL}"
    if webget "$SCRIPTS_PATH" "https://github.com/${SCRIPTS_TGZ_URL}" "echooff" && \
       (verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256" || \
        verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"); then
        success=1
    fi
fi


if [ "$success" -ne 1 ]; then
    log_error "❌  镜像与直连均失败, 安装中止"
    exit 1
fi

# 解压脚本
log_info "📦  解压脚本包..."
tar -xzf "$SCRIPTS_PATH" -C "$CONFIG_DIR"

# 设置权限
chmod +x "$CONFIG_DIR"/*.sh

# 创建helper的软连接
ln -sf "$CONFIG_DIR/helper.sh" /usr/bin/tailscale-helper

# 检查软链接是否创建成功
if [ -L /usr/bin/tailscale-helper ]; then
    log_info "✅  软连接已成功创建：$CONFIG_DIR/helper.sh -> /usr/bin/tailscale-helper"
else
    log_error "❌  创建软连接失败"
fi

# 初始化通知配置
[ -f "$CONFIG_DIR/notify.conf" ] || cat > "$CONFIG_DIR/notify.conf" <<'EOF'
# 通知开关 (1=启用 0=禁用)
NOTIFY_UPDATE=1
NOTIFY_MIRROR_FAIL=1
NOTIFY_EMERGENCY=1

NOTIFY_SERVERCHAN=0
SERVERCHAN_KEY=""
NOTIFY_BARK=0
BARK_KEY=""
NOTIFY_NTFY=0
NTFY_KEY=""
EOF


run_pretest_mirrors() {
    log_info "🔄  下载 pretest_mirrors.sh 并执行测速..."
    url="https://ghproxy.ch3ng.top/https://github.com/CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/pretest_mirrors.sh"
    if webget "$SCRIPTS_PATH" "$url" "echooff"; then  # 这里修正了 if 语句和 then 的位置
        sh /tmp/pretest_mirrors.sh
    else
        return 1
    fi
}

if [ ! -f /etc/tailscale/mirrors.txt ]; then
    log_info "🔍 本地不存在 mirrors.txt, 将下载镜像列表并测速, 请等待..."
    if run_pretest_mirrors; then
        log_info "✅  下载镜像列表并测速完成！"
    else
        log_error "❌  下载或测速失败, 无法继续!"
        exit 1
    fi
else
    log_info "✅  本地存在 mirrors.txt, 无需再次下载!"
fi

log_info "✅  一键安装 Tailscale 配置工具安装完毕!"

