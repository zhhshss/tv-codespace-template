#!/usr/bin/env bash
# 安装模拟器 + API24 x86_64 系统镜像，创建 AVD `tv_ui_api24`（1920x1080 / 320dpi / swiftshader）。
# 幂等。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
SYSTEM_IMAGE="system-images;android-24;default;x86_64"
EMULATOR_PINNED="emulator-linux_x64-11237101.zip"   # 备选：固定版本模拟器

# 1) 模拟器
if [ ! -x "$ANDROID_HOME/emulator/emulator" ]; then
  if ! "$SDKMANAGER" --sdk_root="$ANDROID_HOME" "emulator" 2>/dev/null; then
    echo "sdkmanager 安装模拟器失败，改用固定版本 zip：$EMULATOR_PINNED"
    tmp="$(mktemp -d)"
    curl -fL --retry 3 "https://dl.google.com/android/repository/$EMULATOR_PINNED" -o "$tmp/emulator.zip"
    unzip -q "$tmp/emulator.zip" -d "$ANDROID_HOME"
    rm -rf "$tmp"
  fi
fi

# 2) 系统镜像
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" "$SYSTEM_IMAGE"

# 3) AVD（持久化在 $ANDROID_AVD_HOME）
mkdir -p "$ANDROID_AVD_HOME"
if [ ! -f "$ANDROID_AVD_HOME/${TV_AVD_NAME}.ini" ]; then
  printf 'no\n' | "$AVDMANAGER" create avd \
    -n "$TV_AVD_NAME" -k "$SYSTEM_IMAGE" \
    -p "$ANDROID_AVD_HOME/${TV_AVD_NAME}.avd" --force
fi

# 4) 覆写硬件参数（电视横屏 1080p，软件渲染保证 headless 可用）
CFG="$ANDROID_AVD_HOME/${TV_AVD_NAME}.avd/config.ini"
touch "$CFG"
python3 - "$CFG" <<'PY'
import os
import sys
from pathlib import Path
p = Path(sys.argv[1])
vals = {}
for line in p.read_text().splitlines():
    if '=' in line:
        k, v = line.split('=', 1)
        vals[k.strip()] = v.strip()
vals.update({
    'hw.lcd.width': '1920',
    'hw.lcd.height': '1080',
    'hw.lcd.density': '320',
    'hw.keyboard': 'yes',
    'hw.ramSize': '2048',
    'hw.cpu.ncore': '2',
    'hw.gpu.enabled': 'yes',
    'hw.gpu.mode': 'swiftshader_indirect',
    'disk.dataPartition.size': os.environ['TV_AVD_DATA_SIZE'],
})
p.write_text(''.join(f'{k}={v}\n' for k, v in vals.items()))
print('AVD config 已写入', p)
PY

echo "AVD 就绪：$TV_AVD_NAME"
