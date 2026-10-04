#!/usr/bin/env bash
# 通过 Tailscale 接入测试设备（redroid 容器 / 真机），或列出可用设备。
# 用法：
#   scripts/connect-device.sh                 # 列出 tailnet 设备与 adb 设备
#   scripts/connect-device.sh <ip> [port]     # adb connect <ip>:<port>
#   scripts/connect-device.sh --up            # tailscale up（需 TS_AUTHKEY）
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
ADB="$ANDROID_HOME/platform-tools/adb"

if [ "${1:-}" = "--up" ]; then
  : "${TS_AUTHKEY:?请设置 TS_AUTHKEY（tailscale auth key）}"
  sudo tailscaled --state=/var/lib/tailscale/tailscaled.state >/dev/null 2>&1 &
  sleep 2
  _key_file="$(mktemp)"
  trap 'rm -f "$_key_file"' EXIT
  chmod 600 "$_key_file"
  printf '%s' "$TS_AUTHKEY" > "$_key_file"
  sudo tailscale up --auth-key="file:$_key_file" --accept-routes
  exit 0
fi

if [ -n "${1:-}" ]; then
  PORT="${2:-5555}"
  "$ADB" connect "$1:$PORT"
  "$ADB" -s "$1:$PORT" shell getprop ro.product.model || true
  exit 0
fi

echo "--- tailscale status ---"
tailscale status 2>/dev/null || echo "(tailscale 未运行；用 scripts/connect-device.sh --up 启动)"
echo "--- adb devices ---"
"$ADB" devices -l
