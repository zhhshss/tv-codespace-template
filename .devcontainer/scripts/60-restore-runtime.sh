#!/usr/bin/env bash
# 每次 Codespace 启动后运行：确保运行时目录存在、fixture 兼容软链就位。
# 默认不自动拉起模拟器（避免无谓占用）；需要则设 TV_AUTOSTART=1。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

mkdir -p "$TV_RUNTIME_DIR" "$TV_RESULTS_DIR" "$TV_FIXTURE_ROOT"

if [ "${TV_AUTOSTART:-0}" = "1" ]; then
  bash "$HERE/../../scripts/start-emulator.sh" || true
  bash "$HERE/../../scripts/start-fixture.sh" || true
fi

echo "运行时目录就绪：$TV_RUNTIME_DIR / $TV_RESULTS_DIR / $TV_FIXTURE_ROOT"
