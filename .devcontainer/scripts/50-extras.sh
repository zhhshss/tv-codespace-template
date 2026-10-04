#!/usr/bin/env bash
# 附加工具：uv + Python3.10、fixture 测试素材、gradlew 可执行位。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"

# 1) uv + 独立 Python3.10（若系统已有 python3.10 则跳过）
if ! command -v python3.10 >/dev/null 2>&1; then
  if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  export PATH="$HOME/.local/bin:$PATH"
  uv python install 3.10
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$(uv python find 3.10)" "$HOME/.local/bin/python3.10"
fi
python3.10 --version || true

# 2) fixture 测试素材（海报/壁纸/样片），供 QA 模拟器使用
FIXTURE_SRC="$HERE/../../fixture"
if [ -d "$FIXTURE_SRC" ]; then
  python3 "$FIXTURE_SRC/make-assets.py" "$TV_FIXTURE_ROOT"
  cp -f "$FIXTURE_SRC/server.py" "$TV_FIXTURE_ROOT/server.py"
fi

# 3) gradlew 可执行位
[ -f "$TV_DIR/gradlew" ] && chmod +x "$TV_DIR/gradlew" || true
[ -f "$TV_UI_DIR/gradlew" ] && chmod +x "$TV_UI_DIR/gradlew" || true

echo "附加工具就绪。"
