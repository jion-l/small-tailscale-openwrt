#!/bin/bash
SCRIPT_VERSION="v1.0.22"

# 检查并引入 /etc/tailscale/tools.sh 文件
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh

if [ -s "$VALID_MIRRORS" ]; then
    custom_proxy=$(head -n 1 "$VALID_MIRRORS")
else
    custom_proxy="https://ghproxy.ch3ng.top/https://github.com/"
fi

# 自动判断 curl 和 wget 可用性
get_download_tool() {
    if command -v curl > /dev/null 2>&1; then
        echo "curl"
    elif command -v wget > /dev/null 2>&1; then
        echo "wget"
    else
        log_info "❌ 没有找到 curl 或 wget, 无法下载或执行操作。"
        exit 1
    fi
}

# 获取可用的下载工具
download_tool=$(get_download_tool)

get_remote_version() {
    remote_ver_url="${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/scripts/helper.sh"
    
    if [ "$download_tool" = "curl" ]; then
        # 设置 5 秒超时
        timeout 5 curl -sSL "$remote_ver_url" | grep -E '^SCRIPT_VERSION=' | cut -d'"' -f2 > "$REMOTE_SCRIPTS_VERSION_FILE"
    else
        # 设置 5 秒超时
        timeout 5 wget -qO- "$remote_ver_url" | grep -E '^SCRIPT_VERSION=' | cut -d'"' -f2 > "$REMOTE_SCRIPTS_VERSION_FILE"
    fi
}



show_menu() {
    log_info "🎉  欢迎使用 Tailscale on OpenWRT 管理脚本 $SCRIPT_VERSION"
    if [ ! -s "$REMOTE_SCRIPTS_VERSION_FILE" ]; then
        log_info "⚠️  无法获取远程脚本版本"
    else
        remote_version=$(cat "$REMOTE_SCRIPTS_VERSION_FILE")
        log_info "📦  远程脚本版本: $remote_version $( 
            [ "$remote_version" != "$SCRIPT_VERSION" ] && echo '🚨(有更新, 请按 [9] 更新)' || echo '✅(已是最新)' 
        )"
    fi
    log_info "    请选择操作："
    log_info "1)  📥 安装 / 重装 Tailscale"
    log_info "2)  🚀 启动 Tailscale"
    log_info "3)  🔄 管理 Tailscale 自动更新"
    log_info "4)  📦 查看本地 Tailscale 存在版本"
    log_info "5)  📦 查看远程 Tailscale 最新版本"
    log_info "6)  🔔 管理推送通知"
    log_info "7)  📊 排序代理池"
    log_info "8)  ♻️ 更新代理池"
    log_info "9)  🛠️ 更新脚本包"
    log_info "10) ❌ 卸载 Tailscale"
    log_info "0)  ⛔ 退出"
}


# 处理用户选择
handle_choice() {
    case $1 in
        1)
            /etc/tailscale/setup.sh
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        2)
            tmp_log="/tmp/tailscale_up.log"
            : > "$tmp_log"  # 清空日志文件

            # 后台启动 tailscale up, 输出重定向到日志
            tailscale up >"$tmp_log" 2>&1 &
            up_pid=$!

            log_info "🚀  命令 tailscale up 已运行, 正在监控输出..."

            auth_detected=false
            fail_detected=false

            # 实时监控输出
            tail -n 1 -F "$tmp_log" | while read -r line; do
                echo "$line" | grep -q "not found" && {
                    log_error "❌  tailscale 未安装或命令未找到"
                    kill $up_pid 2>/dev/null
                    break
                }

                echo "$line" | grep -qi "failed" && {
                    log_error "❌  tailscale up 执行失败：$line"
                    fail_detected=true
                    kill $up_pid 2>/dev/null
                    break
                }

                echo "$line" | grep -qE "https://[^ ]*tailscale.com" && {
                    auth_url=$(echo "$line" | grep -oE "https://[^ ]*tailscale.com[^ ]*")
                    log_info "🔗  tailscale 等待认证, 请访问以下网址登录：$auth_url"
                    auth_detected=true
                    # 不退出, 继续等 tailscale up 自然完成
                }

                # tailscale up 正常结束则 break（监控它是否还活着）
                if ! pgrep -x "tailscale" > /dev/null; then
                    if [[ $auth_detected != true && $fail_detected != true ]]; then
                        if [[ -s "$tmp_log" ]]; then
                            log_info "✅  tailscale up 执行完成：$(cat "$tmp_log")"
                        else
                            log_info "✅  tailscale up 执行完成, 无输出"
                        fi
                    fi
                    break
                fi
            done
            ;;
        3)
            /etc/tailscale/update_ctl.sh
            ;;
        4)
            if [ -f "$VERSION_FILE" ]; then
                log_info "📦  当前本地版本: $(cat "$VERSION_FILE")"
            else
                log_info "⚠️  本地未记录版本信息, 可能未安装 Tailscale"
            fi
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        5)
            /etc/tailscale/fetch_and_install.sh --dry-run
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        6)
            /etc/tailscale/notify_ctl.sh
            ;;
        7)
            /etc/tailscale/test_mirrors.sh
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        8)
            if [ "$download_tool" = "curl" ]; then
                curl -sSL -o /tmp/pretest_mirrors.sh "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/pretest_mirrors.sh" && sh /tmp/pretest_mirrors.sh
            else
                wget -O /tmp/pretest_mirrors.sh "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/pretest_mirrors.sh" && sh /tmp/pretest_mirrors.sh
            fi
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        9)
            if [ "$download_tool" = "curl" ]; then
                curl -sSL "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/install.sh" | sh
            else
                wget -O- "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/install.sh" | sh
            fi
            log_info "✅  脚本更新完毕, 请按回车重新加载..."
            read khjfsdjkhfsd
            exec tailscale-helper
            ;;

        10)
            /etc/tailscale/uninstall.sh
            log_info "✅  请按回车继续..."
            read khjfsdjkhfsd
            ;;
        0)
            exit 0
            ;;
        *)
            log_info "❌ 无效选择, 请重新输入, 按回车继续..."
            read khjfsdjkhfsd
            ;;
    esac
}

clear
# 主循环前执行一次远程版本检测
log_info "🔄  正在检测脚本更新 ..."
get_remote_version
clear

# 主循环
while true; do
    show_menu
    log_info "✅  请输入你的选择:"
    read choice
    handle_choice "$choice"
    clear
done