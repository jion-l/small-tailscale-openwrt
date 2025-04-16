#!/bin/sh

set -e

# 参数解析
MODE="local"
while [ $# -gt 0 ]; do
    case "$1" in
        --mode=*) MODE="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 生成服务文件
cat > /etc/init.d/tailscale <<EOF
#!/bin/sh /etc/rc.common
START=99

start() {
    [ -x "/usr/local/bin/tailscaled" ] && exec /usr/local/bin/tailscaled
    [ -x "/tmp/tailscaled" ] && exec /tmp/tailscaled
}

stop() {
    killall tailscaled 2>/dev/null
}
EOF

# 设置权限
chmod +x /etc/init.d/tailscale
/etc/init.d/tailscale enable

# 启动服务
if [ "$MODE" = "local" ]; then
    /etc/init.d/tailscale start
fi