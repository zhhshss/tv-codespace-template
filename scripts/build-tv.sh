#!/usr/bin/env bash
# 构建 TV APK。用法：
#   scripts/build-tv.sh [gradle 任务...]
# 默认：:app:assembleLeanbackArm64_v8aDebug
# 常用：
#   scripts/build-tv.sh :app:assembleLeanbackArm64_v8aDebug
#   scripts/build-tv.sh assembleLeanbackArm64_v8aRelease assembleLeanbackArmeabi_v7aRelease --no-daemon --build-cache --max-workers=2
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

cd "${TV_BUILD_DIR:-$TV_UI_DIR}"
chmod +x ./gradlew

if [ "$#" -eq 0 ]; then
  set -- ":app:assembleLeanbackArm64_v8aDebug"
fi

# AGP 9.x + compileSdk=37 需要 minor API DSL 才能解析 platforms;android-37.0
INIT_SCRIPT="$HERE/../scripts/sdk-compat.init.gradle"
GRADLE_ARGS=()
if [ -f "$INIT_SCRIPT" ]; then
  GRADLE_ARGS+=(-I "$INIT_SCRIPT")
fi

echo "构建目录：$(pwd)"
echo "任务：$*"
./gradlew "${GRADLE_ARGS[@]}" "$@"
