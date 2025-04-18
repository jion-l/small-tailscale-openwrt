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
  [ -f "$CONF_FILE" ] && source "$CONF_FILE"
}

# 保存配置
save_conf() {
  > "$CONF_FILE"
  for key in "${!PARAMS_TYPE[@]}"; do
    value="${!key}"
    [[ -n "$value" ]] && echo "$key=\"$value\"" >> "$CONF_FILE"
  done
}

# 展示当前配置状态
show_status() {
  clear
  echo "当前 tailscale up 参数状态："
  i=1
  for key in "${!PARAMS_TYPE[@]}"; do
    val="${!key}"
    emoji="❌"
    [[ -n "$val" ]] && emoji="✅"
    printf "%2d) [%s] %s %s\n" $i "$emoji" "$key" "${PARAMS_DESC[$key]}"
    OPTIONS[$i]="$key"
    ((i++))
  done
  echo ""
  echo "0) 退出   r) 执行 tailscale up   g) 生成命令"
}

# 修改参数
edit_param() {
  idx=$1
  key="${OPTIONS[$idx]}"
  type="${PARAMS_TYPE[$key]}"
  if [[ "$type" == "flag" ]]; then
    echo -n "启用 $key ? (y/N): "
    read yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      declare -g $key=1
    else
      unset $key
    fi
  else
    echo -n "请输入 $key 的值（${PARAMS_DESC[$key]}）："
    read val
    if [[ -n "$val" ]]; then
      declare -g $key="$val"
    else
      unset $key
    fi
  fi
  save_conf
}

# 生成命令
generate_cmd() {
  cmd="tailscale up"
  for key in "${!PARAMS_TYPE[@]}"; do
    val="${!key}"
    if [[ -n "$val" ]]; then
      [[ "${PARAMS_TYPE[$key]}" == "flag" ]] && cmd+=" $key" || cmd+=" $key=$val"
    fi
  done
  echo -e "\n生成命令："
  echo "$cmd"
}

# 主循环
main() {
  while true; do
    load_conf
    show_status
    echo -n "请输入要修改的参数编号（0退出，g生成命令，r运行）："
    read input
    if [[ "$input" == "0" ]]; then
      exit 0
    elif [[ "$input" == "g" ]]; then
      generate_cmd
      read -p "按回车继续..."
    elif [[ "$input" == "r" ]]; then
      generate_cmd
      echo -e "\n即将执行..."
      eval $cmd
      exit 0
    elif [[ "$input" =~ ^[0-9]+$ && -n "${OPTIONS[$input]}" ]]; then
      edit_param $input
    fi
  done
}

main