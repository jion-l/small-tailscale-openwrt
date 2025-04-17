#!/bin/sh

set -e

[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

# 参数解析
AUTO_UPDATE=false
while [ $# -gt 0 ]; do
    case "$1" in
        --auto-update=*) AUTO_UPDATE="${1#*=}"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 清除旧配置
sed -i "\|$CONFIG_DIR/|d" /etc/crontabs/root

# 添加镜像维护任务
echo "0 4 * * * $CONFIG_DIR/mirror_maintenance.sh" >> /etc/crontabs/root

# 添加自动更新任务
if [ "$AUTO_UPDATE" = "true" ]; then
    echo "0 3 * * * $CONFIG_DIR/autoupdate.sh" >> /etc/crontabs/root
fi

# 重启cron服务
/etc/init.d/cron restart