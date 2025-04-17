#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh


# 如果没有 auto_update_enabled 文件，跳过更新
[ ! -f "$CONFIG_DIR/auto_update_enabled" ] && { echo "⚠️ 您未开启自动更新, 请运行 /etc/tailscale/update_ctl.sh 进行更改"; exit 0; }


# 加载配置文件
safe_source "$INST_CONF" || { log_error "无法加载配置文件 $INST_CONF"; exit 1; }
safe_source "$NTF_CONF" || { log_error "无法加载通知配置文件 $NTF_CONF"; exit 1; }

log_info "正在自动更新..."

# 获取当前版本
if [ -f "$CONFIG_DIR/current_version" ]; then
    current=$(cat "$CONFIG_DIR/current_version")
else
    current="unknown"
fi


log_info "当前版本: $current"

# 获取最新版本
if latest=$("$CONFIG_DIR/fetch_and_install.sh" --dry-run 2>/dev/null); then
    log_info "最新版本: $latest"
else
    log_error "无法获取最新版本，跳过更新"
    exit 0
fi


log_info "最新版本: $latest"

# 版本比对，如果相同则跳过更新
if [ "$latest" = "$current" ]; then
    log_info "当前已是最新版本，跳过更新"
    exit 0
fi

# 执行更新
log_info "发现新版本: $current -> $latest"
log_info "正在执行更新..."

if "$CONFIG_DIR/fetch_and_install.sh" --version="$latest" --mode="$MODE" --mirror-list="$VALID_MIRRORS"; then
    log_info "自动更新成功，正在重启 Tailscale..."
    /etc/init.d/tailscale restart
    send_notify "UPDATE" "更新成功" "✅ 从 $current 升级到 $latest"
    echo "$latest" > "$CONFIG_DIR/current_version"
else
    log_error "自动更新失败！"
    send_notify "EMERGENCY" "更新失败" "❌ 当前: $current\n目标: $latest"
    exit 1
fi
