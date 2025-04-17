#!/bin/sh

set -e
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh
echo "📥 已进入 setup_service.sh"

# 参数解析
MODE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --mode=*) MODE="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 尝试从配置文件读取 MODE
[ -z "$MODE" ] && [ -f "$INST_CONF" ] && safe_source "$INST_CONF"
MODE=${MODE:-local}

# 生成服务文件
cat > /etc/init.d/tailscale <<"EOF"
#!/bin/sh /etc/rc.common

# 版权声明 2020 Google LLC.
# SPDX-License-Identifier: Apache-2.0

USE_PROCD=1
START=90
STOP=1

start_service() {
  # 本地模式
  if [ "$MODE" = "local" ]; then
    echo "🧩 检测到 Local 模式，直接启动 Tailscale..."
    TAILSCALED_BIN="/usr/local/bin/tailscaled"

    procd_open_instance
    procd_set_param env TS_DEBUG_FIREWALL_MODE=auto
    procd_set_param command "$TAILSCALED_BIN"

    # 设置监听 VPN 数据包的端口
    procd_append_param command --port 41641

    # OpenWRT 系统中 /var 是 /tmp 的符号链接，因此将持久状态写入其他位置
    procd_append_param command --state /etc/config/tailscaled.state

    # 为 TLS 证书和 Taildrop 文件保持持久存储
    procd_append_param command --statedir /etc/tailscale/

    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param logfile /var/log/tailscale.log

    procd_close_instance

  # 临时模式
  elif [ "$MODE" = "tmp" ]; then
    echo "🧩 检测到 tmp 模式，恢复开机自动安装最新 Tailscale..."

    # 启动时重新下载并安装最新的 Tailscale
    /etc/tailscale/setup.sh --tmp --auto-update > /tmp/tailscale_boot.log 2>&1 &

  else
    echo "❌ 错误：未知模式 $MODE"
    exit 1
  fi
}

stop_service() {
  # 尝试清理
  [ -x "/usr/local/bin/tailscaled" ] && /usr/local/bin/tailscaled --cleanup
  [ -x "/tmp/tailscaled" ] && /tmp/tailscaled --cleanup
  killall tailscaled 2>/dev/null
}
EOF

# 设置权限
chmod +x /etc/init.d/tailscale
/etc/init.d/tailscale enable

# 启动服务
/etc/init.d/tailscale restart || /etc/init.d/tailscale start
