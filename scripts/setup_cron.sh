#!/bin/sh

set -e
[ -f /etc/tailscale/common.sh ] && . /etc/tailscale/common.sh

# 参数解析
AUTO_UPDATE=false
while [ $# -gt 0 ]; do
    case "$1" in
        --auto-update=*) 
            AUTO_UPDATE="${1#*=}"
            if [ "$AUTO_UPDATE" != "true" ] && [ "$AUTO_UPDATE" != "false" ]; then
                echo "❌ 错误：--auto-update 参数值应为 true 或 false"
                exit 1
            fi
            shift
            ;;
        *)
            echo "❌ 错误：未知参数: $1"
            exit 1
            ;;
    esac
done


# 清除旧配置
log_info "⏰ 清除旧的定时任务配置..."
sed -i "\|$CONFIG_DIR/|d" /etc/crontabs/root || { echo "❌ 清除旧配置失败"; exit 1; }

# 添加镜像维护任务
log_info "⏰ 添加镜像维护任务..."
echo "0 3 * * * $CONFIG_DIR/test_mirrors.sh" >> /etc/crontabs/root || { echo "❌ 添加镜像维护任务失败"; exit 1; }


log_info "⏰ 添加自动更新任务..."
echo "0 4 * * * $CONFIG_DIR/autoupdate.sh" >> /etc/crontabs/root || { echo "❌ 添加自动更新任务失败"; exit 1; }


# 重启cron服务
log_info "⏰ 重启cron服务..."
/etc/init.d/cron restart || { echo "❌ 重启cron服务失败"; exit 1; }

log_info "⏰ 定时任务配置完成！"
