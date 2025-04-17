#!/bin/sh

set -e
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

# 加载配置文件
safe_source "$INST_CONF" || { echo "❌ 无法加载配置文件 $INST_CONF"; exit 1; }

# 确保配置文件中有 MODE
if [ -z "$MODE" ]; then
    echo "❌ 错误：未在配置文件中找到 MODE 设置"
    exit 1
fi

echo "当前的 MODE 设置为: $MODE"

# 生成服务文件
cat > /etc/init.d/tailscale <<"EOF"
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=90
STOP=1

start_service() {
  # 确保已经加载了 INST_CONF 和其中的 MODE
  [ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh
  safe_source "$INST_CONF"

  echo "当前的 MODE 设置为: $MODE"

  if [ "$MODE" = "local" ]; then
    # 本地模式的启动逻辑
    TAILSCALED_BIN="/usr/local/bin/tailscaled"
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
    # 临时模式的启动逻辑
    echo "🧩 使用 tmp 模式"
    /etc/tailscale/setup.sh --tmp --auto-update > /tmp/tailscale_boot.log 2>&1 &
  else
    echo "❌ 错误：未知模式 $MODE"
    exit 1
  fi
}

stop_service() {
  [ -x "/usr/local/bin/tailscaled" ] && /usr/local/bin/tailscaled --cleanup
  [ -x "/tmp/tailscaled" ] && /tmp/tailscaled --cleanup
  killall tailscaled 2>/dev/null
}
EOF

# 设置权限
chmod +x /etc/init.d/tailscale
/etc/init.d/tailscale enable

# 启动服务并不显示任何状态输出
/etc/init.d/tailscale restart > /dev/null 2>&1 || /etc/init.d/tailscale start > /dev/null 2>&1
