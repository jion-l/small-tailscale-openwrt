#!/bin/sh
set -e

CONFIG_DIR="/etc/tailscale"
SCRIPTS_TGZ_URL="CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/tailscale-openwrt-scripts.tar.gz"

# 预先计算的校验和
EXPECTED_CHECKSUM_SHA256="7b7a906e5f3f10b3f34390551c0ef2a099e288f8e39db664a66113ae06d16724"
EXPECTED_CHECKSUM_MD5="201208bc37b584c3c8fe4fe19c985c02"

# 校验函数，接收三个参数：文件路径、校验类型（sha256/md5）、预期值
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
                echo "❌ 系统缺少 sha256sum 或 openssl，无法校验文件"
                return 1
            fi
            ;;
        md5)
            if command -v md5sum >/dev/null 2>&1; then
                actual=$(md5sum "$file" | awk '{print $1}')
            elif command -v openssl >/dev/null 2>&1; then
                actual=$(openssl dgst -md5 "$file" | awk '{print $2}')
            else
                echo "❌ 系统缺少 md5sum 或 openssl，无法校验文件"
                return 1
            fi
            ;;
        *)
            echo "❌ 校验类型无效: $type"
            return 1
            ;;
    esac

    # 校验结果对比
    if [ "$actual" != "$expected" ]; then
        echo "❌ 校验失败！预期: $expected，实际: $actual"
        return 1
    fi

    echo "✅ 校验通过"
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

# 使用有效镜像代理进行下载
mirror_fetch() {
    local real_url=$1
    local output=$2
    local mirror_list_file="$CONFIG_DIR/valid_mirrors.txt"

    if [ -f "$mirror_list_file" ]; then
        while read -r mirror; do
            mirror=$(echo "$mirror" | sed 's|/*$|/|')  # 去掉结尾斜杠
            full_url="${mirror}${real_url}"
            echo "Trying mirror: $full_url"
            if webget "$output" "$full_url" "echooff"; then
                return 0
            fi
        done < "$mirror_list_file"
    fi

    # 如果所有代理都失败，尝试直接下载
    echo "Trying direct: $real_url"
    webget "$output" "$real_url" "echooff"
}

SCRIPTS_PATH="/tmp/tailscale-openwrt-scripts.tar.gz"
success=0

# 检查镜像并下载
if [ -f "$CONFIG_DIR/valid_mirrors.txt" ]; then
    while read -r mirror; do
        mirror=$(echo "$mirror" | sed 's|/*$|/|')
        full_url="${mirror}${SCRIPTS_TGZ_URL}"
        echo "⬇️  尝试镜像: $full_url"

        if webget "$SCRIPTS_PATH" "$full_url" "echooff"; then
            if verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256"; then
                success=1
                break
            else
                echo "⚠️ SHA256校验失败，尝试下一个镜像"
            fi
            if verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"; then
                success=1
                break
            else
                echo "⚠️ MD5校验失败，尝试下一个镜像"
            fi
        fi
    done < "$CONFIG_DIR/valid_mirrors.txt"
fi

# 所有镜像失败后尝试直连
if [ "$success" -ne 1 ]; then
    echo "⬇️  尝试直连: $SCRIPTS_TGZ_URL"
    if webget "$SCRIPTS_PATH" "$SCRIPTS_TGZ_URL" "echooff" && \
       verify_checksum "$SCRIPTS_PATH" "sha256" "$EXPECTED_CHECKSUM_SHA256"; then
        success=1
    fi
    if [ "$success" -ne 1 ]; then
        if webget "$SCRIPTS_PATH" "$SCRIPTS_TGZ_URL" "echooff" && \
           verify_checksum "$SCRIPTS_PATH" "md5" "$EXPECTED_CHECKSUM_MD5"; then
            success=1
        fi
    fi
fi

if [ "$success" -ne 1 ]; then
    echo "❌ 所有镜像与直连均失败，安装中止"
    echo "当前可用镜像地址列表 /etc/tailscale/valid_mirrors.txt 为:"
    cat /etc/tailscale/valid_mirrors.txt
    echo "您可能需要运行 /etc/tailscale/test_mirrors.sh 更新代理地址"
    exit 1
fi

# 解压脚本
echo "📦 解压脚本包..."
tar -xzf "$SCRIPTS_PATH" -C "$CONFIG_DIR"

# 设置权限
chmod +x "$CONFIG_DIR"/*.sh

# 创建helper的软连接
ln -sf "$CONFIG_DIR/helper.sh" /usr/bin/tailscale-helper

# 检查软链接是否创建成功
if [ -L /usr/bin/tailscale-helper ]; then
    echo "✅ 软连接已成功创建：$CONFIG_DIR/helper.sh -> /usr/bin/tailscale-helper, 您可以以后运行 tailscale-helper 来快捷操作"
else
    echo "❌ 创建软连接失败"
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


echo "✅ 脚本包安装完成！请执行以下命令进行安装："
echo "tailscale-helper"