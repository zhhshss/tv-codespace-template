# TV Android 构建/模拟器环境 —— 基础镜像层
# 说明：JDK21 / Python3.10 / Node / gh 由 devcontainer features 安装（见 devcontainer.json）。
#       这里只装系统级依赖：ffmpeg(录屏分析)、PIL(素材生成)、adb、tailscale(真机联调)、unzip/curl。
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget unzip zip jq git util-linux \
      ffmpeg python3-pil python3-requests \
      adb \
      libpulse0 libnss3 libxcomposite1 libxcursor1 libxi6 libxtst6 libxrandr2 libasound2t64 \
 && rm -rf /var/lib/apt/lists/*

# Tailscale（真机/容器测试设备联调用；不在构建期启动守护进程）
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
      | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null \
 && curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
      | tee /etc/apt/sources.list.d/tailscale.list >/dev/null \
 && apt-get update \
 && apt-get install -y --no-install-recommends tailscale \
 && rm -rf /var/lib/apt/lists/*

# 工作区与产物目录（Codespaces 会挂载 /workspaces；本地 docker 也能跑）
RUN mkdir -p /workspaces && chown -R vscode:vscode /workspaces
