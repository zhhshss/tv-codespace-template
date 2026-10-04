#!/usr/bin/env bash
# Codespace 创建后一次性引导：安装 Android SDK / 模拟器 / AVD / 仓库 / 附加工具。
# 幂等：可重复执行。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/env.sh
source "$HERE/../scripts/env.sh"

echo "==> [postCreate] 环境变量"
echo "    JAVA_HOME=$JAVA_HOME"
echo "    ANDROID_HOME=$ANDROID_HOME"
echo "    ANDROID_AVD_HOME=$ANDROID_AVD_HOME"

for step in 10-system.sh 20-android-sdk.sh 30-emulator-avd.sh 40-repos.sh 50-extras.sh; do
  echo "==> [postCreate] $step"
  bash "$HERE/scripts/$step"
done

echo "==> [postCreate] 完成。打开新终端后执行： source scripts/env.sh"
