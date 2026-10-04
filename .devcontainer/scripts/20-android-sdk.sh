#!/usr/bin/env bash
# 安装 Android SDK（cmdline-tools + platform-tools + android-37 + build-tools 37.0.0）。
# 对应 TV 仓库 LOCAL_BUILD_ENV.md。幂等。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

CMDLINE_VERSION="${CMDLINE_VERSION:-13114758}"   # commandlinetools-linux-<ver>_latest.zip
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

mkdir -p "$ANDROID_HOME/cmdline-tools" "$ANDROID_HOME/licenses"

if [ ! -x "$SDKMANAGER" ]; then
  echo "下载 Android cmdline-tools ($CMDLINE_VERSION)"
  tmp="$(mktemp -d)"
  curl -fL --retry 3 \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VERSION}_latest.zip" \
    -o "$tmp/cmdline-tools.zip"
  unzip -q "$tmp/cmdline-tools.zip" -d "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest" "$tmp"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi

export ANDROID_HOME ANDROID_SDK_ROOT
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" --sdk_root="$ANDROID_HOME" \
  "platform-tools" "platforms;android-37.0" "build-tools;37.0.0"

# ---- SDK target 说明（重要） ----
# sdkmanager 只提供 'platforms;android-37.0'（没有不带 .0 的包），而 AGP 9.x 用
# 整数 compileSdk=37 时会去找 target 'android-37'，直接报
#   Failed to find target with hash string 'android-37'
# 已实测无效的做法：把目录软链/改名为 android-37 —— AGP 会判为
#   "package id in inconsistent location" 并自行把 android-37.0 装回来，仍然找不到。
# 有效做法（本项目云端 R3C 验证过）：用官方 minor API DSL，
# 见 scripts/sdk-compat.init.gradle，build-tv.sh 会自动带上。
PLATFORMS="$ANDROID_HOME/platforms"
# 清理早期版本脚本可能留下的软链（AGP 不认）
if [ -L "$PLATFORMS/android-37" ]; then
  rm -f "$PLATFORMS/android-37"
fi

# 让 adb 全局可用
sudo ln -sfn "$ANDROID_HOME/platform-tools/adb" /usr/local/bin/adb 2>/dev/null || true

echo "SDK 就绪：$(ls "$ANDROID_HOME/platforms" | tr '\n' ' ')"
