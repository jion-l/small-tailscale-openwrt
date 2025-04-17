# 小型化 Tailscale 在 OpenWRT 上的一键安装方案

# 安装已经可以使用了,自动更新等功能性脚本还有待维护

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
### 1.先检测镜像可用性
```bash
curl -o /tmp/pretest_mirrors.sh -L https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/pretest_mirrors.sh && sh /tmp/pretest_mirrors.sh
```
或
```bash
wget -O /tmp/pretest_mirrors.sh https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/pretest_mirrors.sh && sh /tmp/pretest_mirrors.sh
```

### 2.下载安装脚本包
```bash
curl -sSL https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/install.sh | sh
```
或
```bash
wget -O- https://ghproxy.ch3ng.top/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/install.sh | sh
```
### 3.开始安装
```bash
/etc/tailscale/setup.sh
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
