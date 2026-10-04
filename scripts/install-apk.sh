#!/usr/bin/env bash
# 安装 APK 到模拟器或真机。用法：
#   scripts/install-apk.sh <apk 路径> [adb serial]
# 默认 serial： emulator-<TV_EMULATOR_PORT>
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

APK="${1:?用法: install-apk.sh <apk> [serial]}"
SERIAL="${2:-emulator-${TV_EMULATOR_PORT}}"
ADB="$ANDROID_HOME/platform-tools/adb"

[ -f "$APK" ] || { echo "APK 不存在：$APK"; exit 1; }
echo "安装 $APK -> $SERIAL"
# --no-streaming 更稳（避免大包 streaming 安装挂起）
"$ADB" -s "$SERIAL" install --no-streaming -r "$APK"
