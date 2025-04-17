#!/bin/sh

CONFIG_DIR="/etc/tailscale"
INST_CONF="$CONFIG_DIR/inst.conf"
COMMON_SH="$CONFIG_DIR/common.sh"

# 加载通用函数
[ -f "$COMMON_SH" ] && . "$COMMON_SH"

# 默认变量
STARTUP=0
MODE=""
ARCH=""
current=""
remote=""
VALID_MIRRORS="$CONFIG_DIR/mirrors.txt"
VERSION_FILE="$CONFIG_DIR/current_version"

# 处理启动参数
[ "$STARTUP" = "1" ] && startup_flag=1 || startup_flag=0

# 加载配置
safe_source "$INST_CONF"
[ -z "$MODE" ] && log_error "缺少 MODE 配置" && exit 1
[ -z "$ARCH" ] && ARCH="$(uname -m)"
[ -z "$current" ] && current="latest"

# 未启用自动更新
if [ ! -f "$CONFIG_DIR/auto_update_enabled" ]; then
  if [ "$MODE" = "local" ]; then
    [ "$startup_flag" -eq 0 ] && echo "⚠️ 您未开启自动更新, 请运行 /etc/tailscale/update_ctl.sh 进行更改"
    exit 0
  elif [ "$MODE" = "tmp" ]; then
    log_info "🚫 TMP 模式禁用自动更新，仅尝试安装设定版本：$current"
    "$CONFIG_DIR/fetch_and_install.sh" --version="$current" --mode="tmp" --mirror-list="$VALID_MIRRORS"
    exit 0
  fi
fi

# 查询远程最新版本
remote="$(
  "$CONFIG_DIR/webget" --url "https://pkgs.tailscale.com/stable/" \
    | grep -oE 'tailscale_[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n 1 | sed 's/tailscale_//'
)"

# 本地记录的版本（用于判断是否已更新）
recorded=""
[ -f "$VERSION_FILE" ] && recorded=$(cat "$VERSION_FILE")

# local 模式逻辑
if [ "$MODE" = "local" ]; then
  if [ "$remote" = "$recorded" ]; then
    log_info "✅ 本地已是最新版 $remote, 无需更新"
    exit 0
  fi

  if "$CONFIG_DIR/fetch_and_install.sh" --version="$remote" --mode="local" --mirror-list="$VALID_MIRRORS"; then
    echo "$remote" > "$VERSION_FILE"
    [ "$startup_flag" -eq 0 ] && "$CONFIG_DIR/notify.sh" "Tailscale 已更新至 $remote"
  else
    log_error "❌ 更新失败"
    exit 1
  fi

# tmp 模式逻辑
elif [ "$MODE" = "tmp" ]; then
  # 比较当前配置版本与远程
  if [ "$current" = "latest" ]; then
    version_to_use="$remote"
  else
    version_to_use="$current"
  fi

  # 如果当前设定的版本与记录版本一致，则无需更新，仅启动用
  if [ "$version_to_use" = "$recorded" ]; then
    log_info "✅ TMP 当前版本 $version_to_use 已是最新，仅启动"
    "$CONFIG_DIR/fetch_and_install.sh" --version="$version_to_use" --mode="tmp" --mirror-list="$VALID_MIRRORS"
    exit 0
  fi

  # 如果设定版本比记录新，则更新并记录
  if "$CONFIG_DIR/fetch_and_install.sh" --version="$version_to_use" --mode="tmp" --mirror-list="$VALID_MIRRORS"; then
    echo "$version_to_use" > "$VERSION_FILE"
    [ "$startup_flag" -eq 0 ] && "$CONFIG_DIR/notify.sh" "Tailscale TMP 模式已更新至 $version_to_use"
  else
    log_error "❌ TMP 更新失败"
    exit 1
  fi
fi
