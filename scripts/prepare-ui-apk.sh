#!/usr/bin/env bash
# 仅用于 x86_64 模拟器的 UI 验证；产物不含 ARM/Python 播放能力，不能发布。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"
APK="${1:-$TV_UI_DIR/app/build/outputs/apk/leanbackArm64_v8a/debug/app-leanback-arm64_v8a-debug.apk}"
OUTPUT="${2:-$TV_RESULTS_DIR/tv-ui-emulator.apk}"
BUILD_TOOLS="$ANDROID_HOME/build-tools/37.0.0"
[ -f "$APK" ] || { echo "APK 不存在：$APK，请先运行 build-tv.sh"; exit 1; }
if [ "$(realpath -m "$APK")" = "$(realpath -m "$OUTPUT")" ]; then
  echo "输出文件不能覆盖原始 APK"; exit 1
fi
mkdir -p "$TV_RUNTIME_DIR" "$(dirname "$OUTPUT")"
WORK="$(mktemp -d "$TV_RUNTIME_DIR/ui-apk.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
python3 "$HERE/prepare-ui-apk.py" "$APK" "$WORK/unsigned.apk"
"$BUILD_TOOLS/zipalign" -P 16 -f 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"
KEYSTORE="$TV_RUNTIME_DIR/ui-debug.jks"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
    -alias androiddebugkey -dname 'CN=TV UI Emulator,O=Android,C=US' \
    -keyalg RSA -keysize 2048 -validity 10000 >/dev/null 2>&1
fi
"$BUILD_TOOLS/apksigner" sign --ks "$KEYSTORE" --ks-pass pass:android \
  --key-pass pass:android "$WORK/aligned.apk"
"$BUILD_TOOLS/apksigner" verify "$WORK/aligned.apk"
mv "$WORK/aligned.apk" "$OUTPUT"
echo "UI 测试包（仅模拟器）：$OUTPUT"
sha256sum "$OUTPUT"
