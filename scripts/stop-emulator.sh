#!/usr/bin/env bash
# 关闭模拟器。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

SERIAL="emulator-${TV_EMULATOR_PORT}"
timeout 5 "$ANDROID_HOME/platform-tools/adb" -s "$SERIAL" emu kill 2>/dev/null || true
pkill -f "qemu-system.*${TV_AVD_NAME}" 2>/dev/null || true
rm -f "$TV_RESULTS_DIR/emulator.pid"
echo "已关闭 $SERIAL"
