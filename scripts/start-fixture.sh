#!/usr/bin/env bash
# 启动本地 fixture（假影视 API + 素材服务器），供模拟器联调。
# 端口 $TV_FIXTURE_PORT，模拟器通过 10.0.2.2 访问宿主。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/env.sh"

mkdir -p "$TV_FIXTURE_ROOT" "$TV_RESULTS_DIR"

if curl -sf "http://127.0.0.1:${TV_FIXTURE_PORT}/config.json" >/dev/null 2>&1; then
  echo "fixture 已在运行：http://127.0.0.1:${TV_FIXTURE_PORT}"
  exit 0
fi

python3 "$HERE/../fixture/make-assets.py" "$TV_FIXTURE_ROOT"
nohup python3 "$HERE/../fixture/server.py" >"$TV_RESULTS_DIR/fixture-server.log" 2>&1 </dev/null &
echo "$!" > "$TV_RESULTS_DIR/fixture-server.pid"
sleep 1
curl -sf "http://127.0.0.1:${TV_FIXTURE_PORT}/config.json" >/dev/null \
  && echo "fixture 就绪 (PID $(cat "$TV_RESULTS_DIR/fixture-server.pid"))" \
  || { echo "fixture 启动失败，见 $TV_RESULTS_DIR/fixture-server.log"; exit 1; }
