#!/usr/bin/env bash
# 独立引导脚本：在"已存在的 Codespace"里一键装好整套环境（不走 devcontainer）。
# 适合：不能改仓库 .devcontainer、或想快速复现环境的场景。
#
#   bash bootstrap.sh
#
# 幂等，可重复执行。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/.devcontainer/scripts"

echo "==> 安装系统依赖（需要 sudo）"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  openjdk-21-jdk-headless unzip zip curl jq \
  ffmpeg python3-pil python3-requests adb git gh ca-certificates util-linux \
  libpulse0 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 libxrandr2 libasound2t64

if ! command -v tailscale >/dev/null 2>&1; then
  echo "==> 安装 tailscale（真机联调用，可选）"
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq tailscale
fi

for step in 10-system.sh 20-android-sdk.sh 30-emulator-avd.sh 40-repos.sh 50-extras.sh; do
  echo "==> $step"
  bash "$SCRIPTS/$step"
done

echo
echo "==> 引导完成。接下来："
echo "    source scripts/env.sh"
echo "    scripts/start-emulator.sh"
echo "    scripts/start-fixture.sh"
echo "    scripts/build-tv.sh"
