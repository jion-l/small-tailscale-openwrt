#!/bin/sh

set -e
. /etc/tailscale/common.sh

# 参数解析
MODE="local"
while [ $# -gt 0 ]; do
    case "$1" in
        --mode=*) MODE="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 生成服务文件
cat > /etc/init.d/tailscale <<"EOF"
#!/bin/sh /etc/rc.common

# 版权声明 2020 Google LLC.
# SPDX-License-Identifier: Apache-2.0

USE_PROCD=1
START=90
STOP=1

ensure_tailscaled() {
  # 检查tailscaled是否存在且可执行
  if [ ! -x "/usr/local/bin/tailscaled" ]; then
    echo "未在/usr/local/bin/tailscaled找到tailscaled，尝试安装..."

    if [ -x "/etc/tailscale/fetch_and_install.sh" ]; then
      if "/etc/tailscale/fetch_and_install.sh"; then
        echo "tailscaled安装成功"
      else
        echo "安装tailscaled失败"
        return 1
      fi
    else
      echo "安装脚本/etc/tailscale/fetch_and_install.sh不存在或不可执行"
      return 1
    fi

    # 验证安装是否成功
    if [ ! -x "/usr/local/bin/tailscaled" ]; then
      echo "安装尝试后仍未找到tailscaled"
      return 1
    fi
  fi
  return 0
}

start_service() {
  # 首先确保tailscaled可用
  if ! ensure_tailscaled; then
    # 如果/tmp/tailscaled可用则回退
    if [ -x "/tmp/tailscaled" ]; then
      echo "使用位于/tmp/tailscaled的备用版本"
      TAILSCALED_BIN="/tmp/tailscaled"
    else
      echo "错误：找不到有效的tailscaled可执行文件"
      return 1
    fi
  else
    TAILSCALED_BIN="/usr/local/bin/tailscaled"
  fi

  procd_open_instance
  procd_set_param env TS_DEBUG_FIREWALL_MODE=auto
  procd_set_param command "$TAILSCALED_BIN"

  # 设置监听VPN数据包的端口
  procd_append_param command --port 41641

  # OpenWRT系统中/var是/tmp的符号链接，因此将持久状态写入其他位置
  procd_append_param command --state /etc/config/tailscaled.state

  # 为TLS证书和Taildrop文件保持持久存储
  procd_append_param command --statedir /etc/tailscale/

  procd_set_param respawn
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_set_param logfile /var/log/tailscale.log

  procd_close_instance
}

stop_service() {
  # 尝试两个位置的清理操作
  [ -x "/usr/local/bin/tailscaled" ] && /usr/local/bin/tailscaled --cleanup
  [ -x "/tmp/tailscaled" ] && /tmp/tailscaled --cleanup

  # 确保进程已停止
  killall tailscaled 2>/dev/null
}
EOF

# 设置权限
chmod +x /etc/init.d/tailscale
/etc/init.d/tailscale enable

# 启动服务
if [ "$MODE" = "local" ]; then
    /etc/init.d/tailscale restart || /etc/init.d/tailscale start
fi
