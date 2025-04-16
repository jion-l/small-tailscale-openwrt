# Tailscale OpenWrt 安装脚本包

本项目包含用于在 OpenWrt 或其他 Linux 系统上安装优化版 Tailscale 的脚本集合，支持本地/内存安装方式，并带有自动更新功能。

## 📦 包含的文件

- `install.sh`：主安装脚本，可选择本地或内存方式安装。
- `fetch_and_install.sh`：独立下载器/安装器，支持更新。
- `autoupdate.sh`：用于开机自动检查并更新 Tailscale 可执行文件。

## 🚀 安装方式

### 方式一：本地安装

脚本会将 tailscaled 和 tailscale 文件安装到 `/usr/local/bin/`，并创建软链接。支持自动更新功能（可启用或关闭）。

```bash
wget -O install.sh https://raw.githubusercontent.com/CH3NGYZ/tailscale-openwrt/main/install.sh
chmod +x install.sh
./install.sh
```

### 方式二：内存安装（适合只读系统，如 OpenWrt）

脚本会在 `/tmp/` 中放置 tailscaled 和 tailscale 文件（软连接），每次开机需重新执行安装或自动执行。

```bash
wget -O install.sh https://raw.githubusercontent.com/CH3NGYZ/tailscale-openwrt/main/install.sh
chmod +x install.sh
./install.sh --tmp
```

## 🔁 自动更新

- 安装脚本会询问是否启用自动更新
- 自动更新通过 `autoupdate.sh` 实现，可定时或在开机时运行
- 可随时手动运行 `fetch_and_install.sh` 实现更新

---
如需提交 Issue 或 PR，请前往 [CH3NGYZ/tailscale-openwrt](https://github.com/CH3NGYZ/tailscale-openwrt)。
