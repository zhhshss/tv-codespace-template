# shellcheck shell=bash
# TV codespace 统一环境变量。用法： source scripts/env.sh
# 所有路径都可用同名环境变量覆盖。

# 按模板位置加载用户的 shell 配置，从任意目录调用均生效。
_tv_env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [ -f "$_tv_env_file" ]; then
  _tv_allexport=0
  case "$-" in *a*) _tv_allexport=1 ;; esac
  set -a
  source "$_tv_env_file"
  [ "$_tv_allexport" = 1 ] || set +a
  unset _tv_allexport
fi
unset _tv_env_file

export TV_WORKSPACES="${TV_WORKSPACES:-/workspaces}"

# 仓库与工作树
export TV_DIR="${TV_DIR:-$TV_WORKSPACES/TV}"
export TV_UI_DIR="${TV_UI_DIR:-$TV_WORKSPACES/TV-ui-redesign}"
export MEDIA3_SOURCE_DIR="${MEDIA3_SOURCE_DIR:-$TV_DIR/.media3}"

# Android SDK
export ANDROID_HOME="${ANDROID_HOME:-$TV_WORKSPACES/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$TV_WORKSPACES/TV-ui-runtime/avd}"

# 运行时与产物
export TV_RUNTIME_DIR="${TV_RUNTIME_DIR:-$TV_WORKSPACES/TV-ui-runtime}"
export TV_RESULTS_DIR="${TV_RESULTS_DIR:-$TV_WORKSPACES/TV-ui-results}"
export TV_FIXTURE_ROOT="${TV_FIXTURE_ROOT:-/tmp/tv-ui-fixture}"
export TV_FIXTURE_PORT="${TV_FIXTURE_PORT:-8765}"

# 模拟器
export TV_AVD_NAME="${TV_AVD_NAME:-tv_ui_api24}"
export TV_EMULATOR_PORT="${TV_EMULATOR_PORT:-5580}"
export TV_AVD_DATA_SIZE="${TV_AVD_DATA_SIZE:-2G}"
export TV_EMULATOR_TIMEOUT="${TV_EMULATOR_TIMEOUT:-240}"

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$TV_WORKSPACES/.gradle}"

# TV 构建硬要求 JDK 21。Codespaces 默认镜像会预设 JAVA_HOME 为 Java 25，
# 所以不能只判断"是否已设置"：只要不是 21 就重新探测（TV_KEEP_JAVA=1 保留原值）。
if [ "${TV_KEEP_JAVA:-0}" != "1" ] && [ -n "${JAVA_HOME:-}" ] \
   && { [ ! -x "$JAVA_HOME/bin/javac" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -E 'version "21(\.|")' >/dev/null; }; then
  unset JAVA_HOME
fi

# 扫描目录 + 按版本判定；优先带 javac 的完整 JDK（Gradle 需要，JRE 目录不行）。
if [ -z "${JAVA_HOME:-}" ]; then
  _fallback=""
  for _c in /usr/lib/jvm/* /usr/local/sdkman/candidates/java/* "$HOME"/.sdkman/candidates/java/* "$HOME"/java/*; do
    [ -x "$_c/bin/java" ] || continue
    [ -z "$_fallback" ] && _fallback="$_c"
    [ -x "$_c/bin/javac" ] || continue
    if "$_c/bin/java" -version 2>&1 | grep -E 'version "21(\.|")' >/dev/null; then
      JAVA_HOME="$_c"
      break
    fi
  done
  [ -z "${JAVA_HOME:-}" ] && JAVA_HOME="$_fallback"
  unset _c _fallback
fi
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME

export PATH="${JAVA_HOME:-}/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$HOME/.local/bin:$PATH"

# 便捷别名（可选）
tv_adb() { "$ANDROID_HOME/platform-tools/adb" -s "emulator-${TV_EMULATOR_PORT}" "$@"; }
export -f tv_adb 2>/dev/null || true
