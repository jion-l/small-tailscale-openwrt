#!/bin/sh

set -e

CONFIG_DIR="/etc/tailscale"
[ ! -f "$CONFIG_DIR/auto_update_enabled" ] && exit 0
[ -f "$CONFIG_DIR/install.conf" ] && . "$CONFIG_DIR/install.conf"

LATEST=$(curl -s https://api.github.com/repos/CH3NGYZ/ts-test/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
CURRENT=$(cat "$CONFIG_DIR/current_version" 2>/dev/null || echo "unknown")

[ "$LATEST" = "$CURRENT" ] && exit 0

echo "发现新版本: $LATEST (当前: $CURRENT)"
"$CONFIG_DIR/fetch_and_install.sh" --version="$LATEST"
/etc/init.d/tailscale restart