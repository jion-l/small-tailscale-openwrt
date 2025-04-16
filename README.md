# Tailscale OpenWRT 一键管理套件

## 📦 功能特性
- 双模式安装：本地持久化 `/usr/local/bin` 或 内存安装 `/tmp`
- 智能镜像加速：自动选择可用镜像源下载
- 全自动更新：支持定时更新和手动更新
- 完整卸载：一键清除所有相关文件和服务

## 🚀 快速开始
```bash
# 下载安装器
mkdir /etc/tailscale/ && wget -O /etc/tailscale/install.sh https://wget.la/https://raw.githubusercontent.com/CH3NGYZ/ts-test/main/install.sh && chmod +x /etc/tailscale/install.sh
```
```
# 执行安装（推荐本地安装+自动更新）
/etc/tailscale/install.sh --auto-update --version=latest
```

## ⚙️ 管理命令
| 命令 | 功能 |
|------|------|
| `/etc/init.d/tailscale start` | 启动服务 |
| `/etc/init.d/tailscale stop` | 停止服务 |
| `/etc/tailscale/autoupdate_ctl.sh on` | 启用自动更新 |
| `/etc/tailscale/autoupdate_ctl.sh off` | 禁用自动更新 |
| `/etc/tailscale/uninstall.sh` | 完全卸载 |

## 🔧 高级配置
1. **指定安装版本**：
   ```bash
   /etc/tailscale/install.sh --version=v1.44.0
   ```

2. **内存安装模式**：
   ```bash
   /etc/tailscale/install.sh --tmp
   ```

3. **手动立即更新**：
   ```bash
   /etc/tailscale/autoupdate.sh
   ```

## 📂 文件结构
```
/etc/tailscale/
├── install.sh           # 安装入口
├── fetch_and_install.sh # 下载器
├── autoupdate*          # 更新相关
├── uninstall.sh         # 卸载脚本
├── install.conf         # 安装配置
└── mirrors.txt          # 镜像列表
```

## ⚠️ 注意事项
1. 内存安装模式重启后需重新下载
2. 自动更新默认每天03:00执行
3. 卸载脚本会删除所有相关文件和配置
