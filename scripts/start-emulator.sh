#!/usr/bin/env bash
# 启动 headless 模拟器（电视 1080p），等待系统启动完成。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

EMU="$ANDROID_HOME/emulator/emulator"
[ -x "$EMU" ] || { echo "找不到模拟器：$EMU（先跑 .devcontainer/scripts/30-emulator-avd.sh）"; exit 1; }

SERIAL="emulator-${TV_EMULATOR_PORT}"
ADB="$ANDROID_HOME/platform-tools/adb"

if [ "$(timeout 5 "$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" = "1" ]; then
  echo "模拟器已在运行：$SERIAL"
  exit 0
fi

mkdir -p "$TV_RESULTS_DIR"
LOG="$TV_RESULTS_DIR/emulator.log"

DATA_BYTES="$(numfmt --from=iec "$TV_AVD_DATA_SIZE")"
DATA_MB=$((DATA_BYTES / 1024 / 1024))
EMU_ARGS=(-partition-size "$DATA_MB" -avd "$TV_AVD_NAME" -no-window -no-audio -no-boot-anim -no-snapshot -no-metrics
          -gpu swiftshader_indirect -feature -Vulkan
          -cores 2 -memory 2048 -port "$TV_EMULATOR_PORT")

# KVM 权限：Codespaces 里 /dev/kvm 常属于宿主 gid（如 109），而容器内的 kvm 组
# gid 往往不同，usermod 加组无效。这里取 /dev/kvm 的真实 gid，用 setpriv 带着
# 该 gid 启动模拟器（这也是本项目原环境验证过的做法）。
KVM_GID="$(stat -c %g /dev/kvm 2>/dev/null || true)"
LAUNCH=(env ANDROID_AVD_HOME="$ANDROID_AVD_HOME" ANDROID_SDK_ROOT="$ANDROID_HOME" "$EMU" "${EMU_ARGS[@]}")
if [ -e /dev/kvm ] && [ ! -w /dev/kvm ] && [ -n "$KVM_GID" ]; then
  if sudo -n true 2>/dev/null; then
    echo "以 setpriv 携带 kvm gid=$KVM_GID 启动模拟器"
    LAUNCH=(sudo --preserve-env=HOME setpriv --reuid="$(id -u)" --regid="$(id -g)" \
            --groups="$(id -G | tr ' ' ','),$KVM_GID" "${LAUNCH[@]}")
  else
    echo "警告：/dev/kvm 不可写且无免密 sudo，模拟器会非常慢。"
  fi
elif [ -w /dev/kvm ]; then
  LAUNCH=("${LAUNCH[@]}" -accel on)
else
  echo "警告：无 /dev/kvm，模拟器会非常慢（需支持嵌套虚拟化的机型）。"
fi

exec 9>"$TV_RESULTS_DIR/emulator-start.lock"
flock -n 9 || { echo "已有模拟器启动任务，请查看 $LOG"; exit 1; }
if [ -f "$TV_RESULTS_DIR/emulator.pid" ] && kill -0 "$(cat "$TV_RESULTS_DIR/emulator.pid")" 2>/dev/null; then
  echo "模拟器仍在启动，请查看 $LOG（或先运行 stop-emulator.sh）"; exit 1
fi
nohup "${LAUNCH[@]}" >"$LOG" 2>&1 </dev/null 9>&- &
EMU_PID=$!
echo "$EMU_PID" > "$TV_RESULTS_DIR/emulator.pid"
echo "模拟器启动中 (PID $(cat "$TV_RESULTS_DIR/emulator.pid"))，日志：$LOG"

DEADLINE=$((SECONDS + TV_EMULATOR_TIMEOUT))
while [ "$SECONDS" -lt "$DEADLINE" ]; do
  if ! kill -0 "$EMU_PID" 2>/dev/null; then
    echo "模拟器已退出："
    tail -25 "$LOG"
    rm -f "$TV_RESULTS_DIR/emulator.pid"
    exit 1
  fi
  if [ "$(timeout 5 "$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" = "1" ]; then
    "$ADB" -s "$SERIAL" shell settings put system accelerometer_rotation 0 || true
    "$ADB" -s "$SERIAL" shell settings put system user_rotation 0 || true   # 使用 1920x1080 原生方向
    echo "启动完成：$SERIAL"
    exit 0
  fi
  sleep 2
done
echo "启动超时（${TV_EMULATOR_TIMEOUT}s），请查看 $LOG；可用 stop-emulator.sh 停止后重试。"
tail -25 "$LOG"
exit 1
