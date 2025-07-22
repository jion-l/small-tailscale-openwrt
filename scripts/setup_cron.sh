#!/bin/sh

set -e
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

# 参数解析
AUTO_UPDATE=false
while [ $# -gt 0 ]; do
    case "$1" in
        --auto-update=*) 
            AUTO_UPDATE="${1#*=}"
            if [ "$AUTO_UPDATE" != "true" ] && [ "$AUTO_UPDATE" != "false" ]; then
                log_error "❌  错误：--auto-update 参数值应为 true 或 false"
                exit 1
            fi
            shift
            ;;
        *)
            log_error "❌  错误：未知参数: $1"
            exit 1
            ;;
    esac
done


# 清除旧配置
log_info "⏰  清除旧的定时任务配置..."
sed -i "\|$CONFIG_DIR/|d" /etc/crontabs/root || { log_error "❌  清除旧配置失败"; exit 1; }

# 添加镜像维护任务（2:00 ~ 3:59）
RANDOM_HOUR=$((2 + $(awk 'BEGIN{srand(); print int(rand()*2)}')))  # 2 或 3
RANDOM_MIN=$(awk 'BEGIN{srand(); print int(rand()*60)}')
log_info "⏰  添加镜像维护任务..."
echo "$RANDOM_MIN $RANDOM_HOUR * * * $CONFIG_DIR/test_mirrors.sh" >> /etc/crontabs/root || { log_error "❌  添加镜像维护任务失败"; exit 1; }
log_info "⏰  镜像维护任务已设定为 $RANDOM_HOUR 点 $RANDOM_MIN 分"

# 添加自动更新任务（4:00 ~ 6:59）
UPDATE_HOUR=$((4 + $(awk 'BEGIN{srand(); print int(rand()*3)}')))  # 4,5,6
UPDATE_MIN=$(awk 'BEGIN{srand(); print int(rand()*60)}')
log_info "⏰  添加自动更新任务..."
echo "$UPDATE_MIN $UPDATE_HOUR * * * $CONFIG_DIR/autoupdate.sh" >> /etc/crontabs/root || { log_error "❌  添加自动更新任务失败"; exit 1; }
log_info "⏰  自动更新任务已设定为 $UPDATE_HOUR 点 $UPDATE_MIN 分"

# 重启cron服务
log_info "⏰  重启cron服务..."
/etc/init.d/cron restart || { log_error "❌  重启cron服务失败"; exit 1; }

log_info "⏰  定时任务配置完成！"
