#!/bin/bash
[ -f /etc/tailscale/tools.sh ] && . /etc/tailscale/tools.sh
CONF_FILE="$CONFIG_DIR/tailscale_up.conf"

# 参数定义（类型: flag/value, 描述）
declare -A PARAMS_TYPE=(
  ["--accept-dns"]=flag
  ["--accept-risk"]=value
  ["--accept-routes"]=flag
  ["--advertise-exit-node"]=flag
  ["--advertise-routes"]=value
  ["--advertise-tags"]=value
  ["--auth-key"]=value
  ["--exit-node"]=value
  ["--exit-node-allow-lan-access"]=flag
  ["--force-reauth"]=flag
  ["--hostname"]=value
  ["--login-server"]=value
  ["--netfilter-mode"]=value
  ["--operator"]=value
  ["--qr"]=flag
  ["--reset"]=flag
  ["--shields-up"]=flag
  ["--snat-subnet-routes"]=flag
  ["--stateful-filtering"]=flag
  ["--ssh"]=flag
  ["--timeout"]=value
)

# 参数说明
declare -A PARAMS_DESC=(
  ["--accept-dns"]="接受来自管理控制台的 DNS 设置"
  ["--accept-risk"]="接受风险类型并跳过确认（lose-ssh, all 或空）"
  ["--accept-routes"]="接受其他节点广告的子网路由"
  ["--advertise-exit-node"]="提供出口节点功能"
  ["--advertise-routes"]="共享子网路由，填写 IP 段，如 192.168.1.0/24"
  ["--advertise-tags"]="为设备添加标签权限"
  ["--auth-key"]="提供认证密钥自动登录"
  ["--exit-node"]="使用指定出口节点（IP 或名称）"
  ["--exit-node-allow-lan-access"]="允许连接出口节点时访问本地局域网"
  ["--force-reauth"]="强制重新认证"
  ["--hostname"]="使用自定义主机名"
  ["--login-server"]="指定控制服务器 URL"
  ["--netfilter-mode"]="控制防火墙规则：off/nodivert/on"
  ["--operator"]="使用非 root 用户操作 tailscaled"
  ["--qr"]="生成二维码供网页登录"
  ["--reset"]="重置未指定设置"
  ["--shields-up"]="屏蔽来自网络其他设备的连接"
  ["--snat-subnet-routes"]="对子网路由使用源地址转换"
  ["--stateful-filtering"]="启用状态过滤（子网路由器/出口节点）"
  ["--ssh"]="启用 Tailscale SSH 服务"
  ["--timeout"]="tailscaled 初始化超时时间（如10s）"
)

# 加载配置
load_conf() {
  if [ -f "$CONF_FILE" ]; then
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      key=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
      value="${value%\"}"
      value="${value#\"}"
      declare -g "$key=$value"
    done < "$CONF_FILE"
  fi
}


# 保存配置
save_conf() {
  > "$CONF_FILE"
  for key in "${!PARAMS_TYPE[@]}"; do
    var_name=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')  # 转换为合法变量名
    value="${!var_name}"  # 获取转换后的变量值
    [[ -n "$value" ]] && echo "$key=\"$value\"" >> "$CONF_FILE"
  done
}

# 展示状态
show_status() {
  clear
  log_info "当前 tailscale up 参数状态："

  # 计算最大宽度
  max_key_len=0
  max_val_len=0
  for key in "${!PARAMS_TYPE[@]}"; do
    key_len=${#key}
    (( key_len > max_key_len )) && max_key_len=$key_len

    var_name=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    val="${!var_name}"
    val_len=${#val}
    [[ -n "$val" && $val_len -gt $max_val_len ]] && max_val_len=$val_len
  done

  i=1
  for key in "${!PARAMS_TYPE[@]}"; do
    var_name=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    val="${!var_name}"
    emoji="❌"
    [[ -n "$val" ]] && emoji="✅"
    OPTIONS[$i]="$key"

    if [[ -n "$val" ]]; then
      printf "%2d) [%s] %-${max_key_len}s = %-${max_val_len}s # %s\n" \
        $i "$emoji" "$key" "$val" "${PARAMS_DESC[$key]}"
    else
      printf "%2d) [%s] %-${max_key_len}s   %*s# %s\n" \
        $i "$emoji" "$key" $((max_val_len + 3)) "" "${PARAMS_DESC[$key]}"
    fi
    ((i++))
  done

  log_info "⏳  0) 退出   g) 生成带参数的 tailscale up 命令"
  log_info "⏳  输入编号后回车即可修改: " 1
}


# 修改参数
edit_param() {
  idx=$1
  key="${OPTIONS[$idx]}"
  var_name=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')  # 将变量名转换为合法形式
  type="${PARAMS_TYPE[$key]}"
  
  if [[ "$type" == "flag" ]]; then
    # 直接切换 flag 类型的参数
    if [[ -z "${!var_name}" ]]; then
      declare -g $var_name=1  # 如果参数未启用，则启用
      log_info "✅  启用了 $key"
      sleep 1
    else
      unset $var_name  # 否则禁用
      log_info "❌  禁用了 $key"
      sleep 1
    fi
  else
    # 需要用户输入内容的参数
    if [[ -z "${!var_name}" ]]; then
      log_info "🔑  请输入 $key 的值（${PARAMS_DESC[$key]}）：" 1
      read -r val
      if [[ -n "$val" ]]; then
        declare -g $var_name="$val"
        log_info "✅  保存了 $key 的值：$val"
        sleep 1
      fi
    else
      log_info "🔄  当前 $key 的值为 ${!var_name}，按回车继续编辑或输入新值，输入空值将删除该值：" 1
      read -r val
      if [[ -n "$val" ]]; then
        declare -g $var_name="$val"
        log_info "✅  更新了 $key 的值：$val"
        sleep 1
      else
        unset $var_name
        log_info "❌  删除了 $key 的值"
        sleep 1
      fi
    fi
  fi
  save_conf
}



# 生成命令
generate_cmd() {
  cmd="tailscale up"
  for key in "${!PARAMS_TYPE[@]}"; do
    var_name=$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')  # 转换为合法变量名
    val="${!var_name}"  # 获取变量值
    if [[ -n "$val" ]]; then
      if [[ "${PARAMS_TYPE[$key]}" == "flag" ]]; then
        cmd+=" $key"  # 对于 flag 类型的参数，只加上参数名
      else
        cmd+=" $key=$val"  # 对于 value 类型的参数，拼接参数名和值
      fi
    fi
  done
  log_info "⏳  生成命令：" 
  log_info "$cmd"
}

# 主循环
main() {
  while true; do
    load_conf
    show_status
    read input
    if [[ "$input" == "0" ]]; then
      exit 0
    elif [[ "$input" == "g" ]]; then
      generate_cmd
      log_info "⏳  请按回车继续..." 1
      read khjfsdjkhfsd
    elif [[ "$input" =~ ^[0-9]+$ && -n "${OPTIONS[$input]}" ]]; then
      edit_param $input
    fi
  done
}

main
