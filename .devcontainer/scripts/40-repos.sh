#!/usr/bin/env bash
# 克隆主仓库 + Media3，并准备 UI 工作树；保留已有检出与本地修改。
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/env.sh"
TV_REPO="${TV_REPO:-https://github.com/wobuhui666/TV.git}"
TV_REF="${TV_REF:-sync/fongmi-20260628}"
MEDIA_REPO="${MEDIA_REPO:-https://github.com/wobuhui666/media.git}"
MEDIA_REF="${MEDIA_REF:-release-1.11.0-fongmi}"
TV_UI_REF="${TV_UI_REF:-ui/apple-tv-redesign}"

if [ ! -e "$TV_DIR/.git" ]; then
  git clone --filter=blob:none --branch "$TV_REF" "$TV_REPO" "$TV_DIR"
else
  ORIGIN="$(git -C "$TV_DIR" remote get-url origin)"
  if [ "${ORIGIN%.git}" != "${TV_REPO%.git}" ]; then
    echo "注意：已有 TV 仓库 origin 与 TV_REPO 不一致，沿用现有检出。" >&2
  fi
  echo "沿用已有 TV 仓库：$(git -C "$TV_DIR" rev-parse --short HEAD)"
fi

MEDIA_CREATED=0
if [ ! -e "$MEDIA3_SOURCE_DIR/.git" ]; then
  git clone --depth 1 --branch "$MEDIA_REF" "$MEDIA_REPO" "$MEDIA3_SOURCE_DIR"
  MEDIA_CREATED=1
fi

if [ ! -e "$TV_UI_DIR/.git" ]; then
  if ! git -C "$TV_DIR" show-ref --verify --quiet "refs/heads/$TV_UI_REF" &&
     ! git -C "$TV_DIR" show-ref --verify --quiet "refs/remotes/origin/$TV_UI_REF"; then
    if git -C "$TV_DIR" ls-remote --exit-code --heads origin "$TV_UI_REF" >/dev/null; then
      git -C "$TV_DIR" fetch origin "$TV_UI_REF:refs/remotes/origin/$TV_UI_REF"
    fi
  fi
  if git -C "$TV_DIR" show-ref --verify --quiet "refs/heads/$TV_UI_REF" ||
     git -C "$TV_DIR" show-ref --verify --quiet "refs/remotes/origin/$TV_UI_REF"; then
    git -C "$TV_DIR" worktree add "$TV_UI_DIR" "$TV_UI_REF"
  else
    git -C "$TV_DIR" worktree add -b "$TV_UI_REF" "$TV_UI_DIR" "$TV_REF"
  fi
fi

# 使用实际构建工作树中的设置；已有自定义 Media3 设置不覆盖。
SETTINGS_SRC="$TV_UI_DIR/.github/media3-composite-settings.gradle.kts"
[ -f "$SETTINGS_SRC" ] || { echo "缺少 $SETTINGS_SRC，请核对 TV_UI_REF" >&2; exit 1; }
if cmp -s "$SETTINGS_SRC" "$MEDIA3_SOURCE_DIR/settings.gradle.kts"; then
  :
elif [ "$MEDIA_CREATED" = 1 ] || git -C "$MEDIA3_SOURCE_DIR" diff --quiet HEAD -- settings.gradle.kts; then
  cp "$SETTINGS_SRC" "$MEDIA3_SOURCE_DIR/settings.gradle.kts"
else
  echo "保留现有 Media3 settings 修改；请手动核对 $SETTINGS_SRC" >&2
fi

EXCLUDE="$(git -C "$TV_DIR" rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$(dirname "$EXCLUDE")"
grep -qxF '.media3/' "$EXCLUDE" 2>/dev/null || echo '.media3/' >> "$EXCLUDE"
mkdir -p "$TV_RUNTIME_DIR" "$TV_RESULTS_DIR" "$TV_FIXTURE_ROOT"
printf '仓库就绪：\n  TV -> %s\n  UI -> %s\n  Media3 -> %s\n' "$TV_DIR" "$TV_UI_DIR" "$MEDIA3_SOURCE_DIR"
