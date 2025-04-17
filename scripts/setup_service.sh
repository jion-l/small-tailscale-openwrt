#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

# 加载配置文件
log_info "🛠️ 加载配置文件..."
safe_source "$INST_CONF" || { log_error "❌ 无法加载配置文件 $INST_CONF"; exit 1; }

# 确保配置文件中有 MODE 设置
if [ -z "$MODE" ]; then
    log_error "❌ 错误：未在配置文件中找到 MODE 设置"
    exit 1
fi

log_info "🛠️ 当前的 MODE 设置为: $MODE"

# 生成服务文件
log_info "🛠️ 生成服务文件..."
cat > /etc/init.d/tailscale <<"EOF"
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=90
STOP=1

start_service() {
  # 确保已经加载了 INST_CONF 和其中的 MODE
  [ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh
  
  # 加在 start_service 的开始
  if [ "$MODE" = "tmp" ] && [ -f /tmp/.tailscale_tmp_installed ]; then
    log_info "⚠️ 检测到 tailscale 已经通过 setup.sh 启动，跳过重复调用"
    return 0
  fi

  log_info "🛠️ 加载服务启动配置..."
  safe_source "$INST_CONF"

  log_info "🛠️ 当前的 MODE 为: $MODE"

  if [ "$MODE" = "local" ]; then
    # 本地模式的启动逻辑
    TAILSCALED_BIN="/usr/local/bin/tailscaled"
    log_info "🛠️ 启动 Tailscale（本地模式）..."
    procd_open_instance
    procd_set_param env TS_DEBUG_FIREWALL_MODE=auto
    procd_set_param command "$TAILSCALED_BIN"
    procd_append_param command --port 41641
    procd_append_param command --state /etc/config/tailscaled.state
    procd_append_param command --statedir /etc/tailscale/
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param logfile /var/log/tailscale.log
    procd_close_instance

  elif [ "$MODE" = "tmp" ]; then
    log_info "🛠️ 使用临时模式启动 Tailscale..."

    if [ -x /tmp/tailscaled ]; then
        log_info "✅ 检测到临时文件已存在，直接启动 tailscaled..."
        procd_open_instance
        procd_set_param env TS_DEBUG_FIREWALL_MODE=auto
        procd_set_param command /tmp/tailscaled
        procd_append_param command --port 41641
        procd_append_param command --state /etc/config/tailscaled.state
        procd_append_param command --statedir /etc/tailscale/
        procd_set_param respawn
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_set_param logfile /var/log/tailscale.log
        procd_close_instance
        return 0
    fi

    if [ "$AUTO_UPDATE" = "true" ]; then
        log_info "🔄 自动更新启用，安装 latest 版本"
        /etc/tailscale/setup.sh --tmp --auto-update
    else
        VERSION_FILE="$CONFIG_DIR/current_version"
        if [ -f "$VERSION_FILE" ]; then
            version=$(cat "$VERSION_FILE")
            log_info "📦 安装固定版本: $version"
            /etc/tailscale/setup.sh --tmp --version="$version"
        else
            log_error "❌ 无法读取已设定版本号 ($VERSION_FILE)"
            exit 1
        fi
    fi
    log_info "🛠️ 临时模式已启动，日志文件：/tmp/tailscale_boot.log"
  else
    log_error "❌ 错误：未知模式 $MODE"
    exit 1
  fi
}

stop_service() {
  [ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh
  log_info "🛑 停止服务..."
  # 确保正确停止 tailscaled
  if [ -x "/usr/local/bin/tailscaled" ]; then
    /usr/local/bin/tailscaled --cleanup || log_warn "⚠️ 清理失败: /usr/local/bin/tailscaled"
  fi
  if [ -x "/tmp/tailscaled" ]; then
    /tmp/tailscaled --cleanup || log_warn "⚠️ 清理失败: /tmp/tailscaled"
  fi
  killall tailscaled || log_warn "⚠️ 未能停止 tailscaled 服务"
}
EOF

# 设置权限
log_info "🛠️ 设置服务文件权限..."
chmod +x /etc/init.d/tailscale

# 启用服务
log_info "🛠️ 启用 Tailscale 服务..."
/etc/init.d/tailscale enable || { log_error "❌ 启用服务失败"; exit 1; }

# 启动服务并不显示任何状态输出
log_info "🛠️ 启动服务..."
/etc/init.d/tailscale start  || { log_error "❌ 重启服务失败" > /dev/null 2>&1; }

# 完成
log_info "🎉 Tailscale 服务已启动!"
