#!/bin/bash
SCRIPT_VERSION="v1.0.61"

# 检查并引入 /etc/tailscale/tools.sh 文件
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh
custom_proxy="https://ghproxy.ch3ng.top/https://github.com/"
# 自动判断 curl 和 wget 可用性
get_download_tool() {
    if command -v curl > /dev/null 2>&1; then
        echo "curl"
    elif command -v wget > /dev/null 2>&1; then
        echo "wget"
    else
        log_info "❌  没有找到 curl 或 wget, 无法下载或执行操作。"
        exit 1
    fi
}

# 获取可用的下载工具
download_tool=$(get_download_tool)

get_remote_version() {
    remote_ver_url="${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/scripts/helper.sh"
    
    if [ "$download_tool" = "curl" ]; then
        # 设置 5 秒超时
        timeout 6 curl -sSL "$remote_ver_url" | grep -E '^SCRIPT_VERSION=' | cut -d'"' -f2 > "$REMOTE_SCRIPTS_VERSION_FILE"
    else
        # 设置 5 秒超时
        timeout 6 wget -qO- "$remote_ver_url" | grep -E '^SCRIPT_VERSION=' | cut -d'"' -f2 > "$REMOTE_SCRIPTS_VERSION_FILE"
    fi
}

# 添加生成 Tailscale 命令的函数
generate_tailscale_command() {
    log_info "🔓  生成 Tailscale 命令..."
    local tailscale_cmd="tailscale up --authkey=your-auth-key --hostname=your-hostname"
    log_info "执行命令: $tailscale_cmd"
    echo "生成的命令: $tailscale_cmd"
    log_info "✅  请按回车继续..." 1
    read khjfsdjkhfsd
}

show_menu() {
    log_info "🎉  欢迎使用 Tailscale on OpenWRT 管理脚本 $SCRIPT_VERSION"
    if [ ! -s "$REMOTE_SCRIPTS_VERSION_FILE" ]; then
        log_info "⚠️  无法获取远程脚本版本"
    else
        remote_version=$(cat "$REMOTE_SCRIPTS_VERSION_FILE")
        log_info "📦  远程脚本版本: $remote_version $( 
            [ "$remote_version" != "$SCRIPT_VERSION" ] && echo '🚨(脚本有更新, 请使用[🛠️ 更新脚本包]功能)' || echo '✅(已是最新)' 
        )"
    fi
    log_info "    请选择操作："
    log_info "1)  📥 安装 / 重装 Tailscale"
    log_info "2)  🚀 登录 Tailscale"
    log_info "3)  🔓 生成 Tailscale 命令"  # 新增选项
    log_info "4)  🔓 登出 Tailscale"
    log_info "5)  🔄 管理 Tailscale 自动更新"
    log_info "6)  📦 查看本地 Tailscale 存在版本"
    log_info "7)  📦 查看远程 Tailscale 最新版本"
    log_info "8)  🔔 管理推送通知"
    log_info "9)  📊 排序代理池"
    log_info "10) ♻️ 更新代理池"
    log_info "11) 🛠️ 更新脚本包"
    log_info "12) ❌ 卸载 Tailscale"
    log_info "13) 💬 显示 Tailscale 后台服务 安装 / 更新 日志"
    log_info "14) 🔄 手动运行更新脚本"
    log_info "0)  ⛔ 退出"
}

# 处理用户选择
handle_choice() {
    case $1 in
        1)
            $CONFIG_DIR/setup.sh
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        2)
            local tmp_log="/tmp/tailscale_up.log"
            : > "$tmp_log"

            log_info "🚀  执行 tailscale up，正在监控输出..."

            (
                tailscale up >"$tmp_log" 2>&1
                echo "__TS_UP_DONE__" >>"$tmp_log"
            ) &

            local auth_detected=false
            local fail_detected=false

            exec 3< <(tail -n 1 -F "$tmp_log")
            while read -r line <&3; do
                # 检测未安装
                echo "$line" | grep -q "not found" && {
                    log_error "❌  tailscale 未安装或命令未找到"
                    break
                }

                # 执行失败
                echo "$line" | grep -qi "failed" && {
                    log_error "❌  tailscale up 执行失败：$line"
                    fail_detected=true
                    break
                }

                # 检测认证 URL
                echo "$line" | grep -qE "https://[^ ]*tailscale.com" && {
                    auth_url=$(echo "$line" | grep -oE "https://[^ ]*tailscale.com[^ ]*")
                    log_info "🔗  tailscale 等待认证, 请访问以下网址登录：$auth_url"
                    auth_detected=true
                    # 不退出
                }

                # 检测结束标志
                echo "$line" | grep -q "__TS_UP_DONE__" && {
                    if [[ $auth_detected != true && $fail_detected != true ]]; then
                        if [[ -s "$tmp_log" ]]; then
                            log_info "✅  tailscale up 执行完成：$(cat "$tmp_log")"
                        else
                            log_info "✅  tailscale up 执行完成, 无输出"
                        fi
                    fi
                    break
                }
            done

            tailscale status >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log_error "⚠️  tailscale 未登录或状态异常"
            else
                log_info "🎉  tailscale 登录成功，状态正常"
            fi
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        3)  
            $CONFIG_DIR/tailscale_up_generater.sh
            ;;
        4)
            log_info "🔓  正在执行 tailscale logout..."
            if tailscale logout; then
                sleep 3
                if tailscale status 2>&1 | grep -q "Logged out."; then
                    log_info "✅  成功登出 tailscale"
                else
                    log_error "⚠️  登出后状态未知，请检查 tailscale 状态"
                fi
            else
                log_error "❌  tailscale logout 命令执行失败"
            fi
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        5)
            $CONFIG_DIR/update_ctl.sh
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        6)
            if [ -f "$VERSION_FILE" ]; then
                log_info "📦  当前本地版本: $(cat "$VERSION_FILE")"
            else
                log_info "⚠️  本地未记录版本信息, 可能未安装 Tailscale"
            fi
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        7)
            $CONFIG_DIR/fetch_and_install.sh --dry-run
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        8)
            $CONFIG_DIR/notify_ctl.sh
            ;;
        9)
            $CONFIG_DIR/test_mirrors.sh
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        10)
            if [ "$download_tool" = "curl" ]; then
                curl -sSL -o "$MIRROR_LIST" "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/mirrors.txt"
            else
                wget -O "$MIRROR_LIST" "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/mirrors.txt"
            fi
            if [ $? -ne 0 ]; then
                log_error "❌  mirrors.txt下载失败, 请手动将 ${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/mirrors.txt 文件内容复制到本地 $MIRROR_LIST 中"
                exit 0
            fi
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        11)
            if [ "$download_tool" = "curl" ]; then
                curl -sSL "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/install.sh" | sh
            else
                wget -O- "${custom_proxy}CH3NGYZ/small-tailscale-openwrt/raw/refs/heads/main/install.sh" | sh
            fi

            if [ $? -ne 0 ]; then
                log_error "❌  脚本更新失败, 脚本内置作者的代理失效"
                exit 0
            fi

            log_info "✅  脚本更新完毕, 请按回车重新加载..."
            read khjfsdjkhfsd
            exec tailscale-helper
            ;;
        12)
            $CONFIG_DIR/uninstall.sh
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        13)
            cat /tmp/tailscale_update.log
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        14)
            $CONFIG_DIR/autoupdate.sh
            log_info "✅  请按回车继续..." 1
            read khjfsdjkhfsd
            ;;
        0)
            exit 0
            ;;
        *)
            log_info "❌  无效选择, 请重新输入, 按回车继续..." 1
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
    log_info "✅  请输入你的选择: " 1
    read choice
    log_info ""
    handle_choice "$choice"
    clear
done
