#!/usr/bin/env python3
"""生成 fixture 测试素材：海报/壁纸（PIL）+ 样片（ffmpeg）。

用法： python3 make-assets.py [目标目录]
默认目录：$TV_FIXTURE_ROOT 或 /tmp/tv-ui-fixture

产物：
  landscape_1..4.jpg   横版海报 1280x720
  poster_1..4.jpg      竖版海报 480x720
  wallpaper_1..4.webp  壁纸 1920x1080
  sample.mp4           120 秒样片（H.264，带音频轨）
  （故意不生成 missing-artwork.jpg —— 用于测试缺失占位图路径）
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("TV_FIXTURE_ROOT", "/tmp/tv-ui-fixture"))
OUT.mkdir(parents=True, exist_ok=True)

COLORS = [(38, 70, 120), (120, 60, 90), (40, 100, 90), (110, 90, 40)]


def _ffmpeg_solid(path, size, rgb):
    """PIL 缺失时的兜底：用 ffmpeg 生成纯色图（够做布局验证）。"""
    w, h = size
    color = '0x%02x%02x%02x' % rgb
    subprocess.run(
        ['ffmpeg', '-y', '-f', 'lavfi', '-i', f'color=c={color}:s={w}x{h}', '-frames:v', '1', str(path)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def gen_images():
    try:
        from PIL import Image, ImageDraw
        have_pil = True
    except ImportError:
        have_pil = False

    if not have_pil and not shutil.which('ffmpeg'):
        print('缺少 Pillow 且无 ffmpeg，无法生成图片素材（apt install python3-pil ffmpeg）', file=sys.stderr)
        raise SystemExit(1)

    for i in range(4):
        for kind, size, name in (
            ('landscape', (1280, 720), f'landscape_{i + 1}.jpg'),
            ('poster', (480, 720), f'poster_{i + 1}.jpg'),
            ('wallpaper', (1920, 1080), f'wallpaper_{i + 1}.webp'),
        ):
            path = OUT / name
            if path.is_file() and path.stat().st_size > 0:
                continue
            if have_pil:
                img = Image.new('RGB', size, COLORS[i])
                d = ImageDraw.Draw(img)
                d.rectangle([8, 8, size[0] - 8, size[1] - 8], outline=(230, 230, 230), width=3)
                text = f'TV fixture {i + 1}\n{kind} {i + 1}'
                d.multiline_text((size[0] // 12, size[1] // 2 - 40), text, fill=(245, 245, 245))
                img.save(path, quality=85)
            else:
                try:
                    _ffmpeg_solid(path, size, COLORS[i])
                except subprocess.CalledProcessError:
                    raise SystemExit(f'生成 {name} 失败（ffmpeg 缺编码器？）')
    print(f'图片素材 -> {OUT}')


def gen_video():
    if not shutil.which('ffmpeg'):
        raise SystemExit('缺少 ffmpeg，无法生成播放样片')
    target = OUT / 'sample.mp4'
    if target.exists() and target.stat().st_size > 0:
        print(f'样片已存在：{target}')
        return
    subprocess.run([
        'ffmpeg', '-y', '-f', 'lavfi', '-i', 'testsrc=size=640x360:rate=24:duration=120',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=120',
        '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(target),
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f'样片 -> {target}')


if __name__ == '__main__':
    gen_images()
    gen_video()
