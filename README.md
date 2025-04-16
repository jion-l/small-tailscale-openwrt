# Tailscale OpenWRT 一键安装方案

# 项目暂时还不可用!!!,请耐心等待我写完脚本并测试

## 📦 文件结构
```
/etc/tailscale/
├── install.sh             # 基础安装
├── setup.sh               # 主配置脚本
├── fetch_and_install.sh   # 下载安装器
├── test_mirrors.sh        # 代理检测
├── autoupdate.sh          # 自动更新
├── mirror_maintenance.sh  # 镜像维护
├── setup_service.sh       # 服务配置
├── setup_cron.sh          # 定时任务
├── notify_ctl.sh          # 通知管理
├── update_ctl.sh          # 更新控制
├── uninstall.sh           # 卸载脚本
├── install.conf           # 安装配置
├── mirrors.txt            # 镜像列表
├── valid_mirrors.txt      # 有效镜像
└── mirror_scores.txt      # 镜像评分
```

## 🚀 快速安装
```bash
# 一键安装管理脚本
mkdir -p /etc/tailscale && \
curl -sSL https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/install.sh | sh
```

```bash
# 完成配置（本地安装+自动更新）
/etc/tailscale/setup.sh --auto-update
```

## 🔧 日常管理
| 命令 | 功能 |
|------|------|
| `update_ctl.sh on` | 启用自动更新 |
| `notify_ctl.sh` | 配置通知 |
| `test_mirrors.sh` | 检测代理 |
| `fetch_and_install.sh --dry-run` | 检查新版本 |

## ⚙️ 版本管理
```bash
# 安装特定版本
/etc/tailscale/fetch_and_install.sh --version=v1.44.0

# 强制重新检测代理
rm /etc/tailscale/valid_mirrors.txt && /etc/tailscale/test_mirrors.sh
```

## 📡 代理配置
1. 编辑镜像列表：
   ```bash
   nano /etc/tailscale/mirrors.txt
   ```
   格式示例：
   ```
   https://wget.la/
   https://ghproxy.net/
   ```

## 🔔 通知系统
```bash
# 交互式配置
/etc/tailscale/notify_ctl.sh

# 配置项说明：
# - 更新通知：版本升级成功时提醒
# - 代理失败：超过50%镜像不可用时提醒
# - 紧急通知：关键系统错误提醒
```

## 🗑️ 完全卸载
```bash
/etc/tailscale/uninstall.sh
```
> 注意：默认会保留配置目录

## ⚠️ 注意事项
1. 内存安装模式(`--tmp`)重启后需重新下载
2. 首次使用建议配置通知
3. 自动更新默认关闭
