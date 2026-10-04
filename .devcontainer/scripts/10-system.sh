#!/usr/bin/env bash
# 系统级检查：JDK / Python / ffmpeg / kvm 组。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

echo "--- java ---"
java -version
if [ "${TV_KEEP_JAVA:-0}" != 1 ]; then
  javac -version 2>&1 | grep -E '^javac 21(\.|$)' >/dev/null || { echo "缺少完整 JDK 21"; exit 1; }
fi

echo "--- python ---"
python3 --version

echo "--- ffmpeg ---"
ffmpeg -version 2>/dev/null | head -1 || echo "警告：缺少 ffmpeg（录屏分析需要）"

echo "--- /dev/kvm ---"
if [ -e /dev/kvm ]; then
  ls -l /dev/kvm
  if [ -w /dev/kvm ]; then
    echo "当前进程可写，模拟器可硬件加速。"
  else
    echo "当前进程不可写。注意：Codespaces 的 /dev/kvm 常属于宿主 gid（如 109），"
    echo "与容器内 kvm 组 gid 不同，usermod 加组无效；start-emulator.sh 会用 setpriv 处理。"
  fi
else
  echo "警告：无 /dev/kvm，x86_64 模拟器只能软件加速（很慢）。"
  echo "      Codespaces 请使用 4 核及以上机型；或在支持嵌套虚拟化的宿主上运行。"
fi
