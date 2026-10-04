#!/usr/bin/env python3
"""本地 fixture 服务：伪造影视点播/直播 API + 素材，供 TV 模拟器联调。

端口默认 8765。模拟器访问宿主用 10.0.2.2:8765。
素材目录由环境变量 TV_FIXTURE_ROOT 指定（默认 /tmp/tv-ui-fixture）。

接口：
  GET /config.json         站点/直播配置（App 的订阅源）
  GET /api?ids=..&wd=..    点播列表/详情/搜索
  GET /live.m3u            直播源
  GET /sample.mp4          带 Range 的样片
  GET /<图片>              海报/壁纸静态素材
"""
import http.server
import json
import os
import re
import time
import urllib.parse
from pathlib import Path

ROOT = Path(os.environ.get("TV_FIXTURE_ROOT", "/tmp/tv-ui-fixture"))
ROOT.mkdir(parents=True, exist_ok=True)
PORT = int(os.environ.get("TV_FIXTURE_PORT", "8765"))
BASE = os.environ.get("TV_FIXTURE_BASE", "http://10.0.2.2:%d" % PORT)

names = ['深空回声', '远山来信', '城市的夜', '岛屿日记', '冬日旅人', '海岸线', '星光之间', '无声的旅程']
catalogue = [
    dict(
        vod_id=str(i + 1),
        vod_name=name,
        vod_pic=f'{BASE}/wallpaper_{i % 4 + 1}.webp',
        vod_year=str(2026 - i % 3),
        type_name='电影' if i % 2 == 0 else '剧集',
        vod_area='演示地区',
        vod_lang='中文',
        vod_remarks='更新至第 4 集' if i % 2 else '完整影片',
        vod_actor='林一 / 叶青',
        vod_director='陈远',
        vod_content='一段关于相遇、远行与归途的故事。人物在平凡的生活里寻找新的方向，'
                    '也发现那些始终陪伴自己的微小光亮。此为界面验证使用的虚构影片。',
        vod_play_from='演示线路',
        vod_play_url='#'.join(f'第 {j} 集${BASE}/sample.mp4?episode={j}' for j in range(1, 9)),
    )
    for i, name in enumerate(names)
]
catalogue[6]['vod_pic'] = BASE + '/missing-artwork.jpg'   # 故意缺失，测试占位图
for i, v in enumerate(catalogue):
    if i != 6:
        v['vod_pic'] = BASE + ('/landscape_' if i % 2 == 0 else '/poster_') + str(i % 4 + 1) + '.jpg'

config = {
    'sites': [{'key': 'demo', 'name': '演示片库', 'type': 1, 'api': BASE + '/api',
               'searchable': 1, 'quickSearch': 1, 'filterable': 0}],
    'lives': [{'name': '演示直播', 'url': BASE + '/live.m3u', 'epg': BASE + '/epg.xml'}],
}
config['sites'].append(dict(config['sites'][0], key='demo2', name='备用片库'))
(ROOT / 'config.json').write_text(json.dumps(config, ensure_ascii=False))
(ROOT / 'live.m3u').write_text(
    '#EXTM3U\n' + ''.join(
        f'#EXTINF:-1 tvg-id="demo{i}" tvg-name="{n}" group-title="'
        + ('精选频道' if i < 4 else '纪录频道')
        + f'",{n}\n{BASE}/sample.mp4?channel={i}\n'
        for i, n in enumerate(['风景频道', '电影频道', '城市频道', '旅行频道', '自然纪实', '人文故事'], 1)
    )
)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

    def do_GET(self):
        query = urllib.parse.urlsplit(self.path)
        if query.path == '/api':
            params = urllib.parse.parse_qs(query.query)
            rows = catalogue
            if 'ids' in params:
                rows = [v for v in rows if v['vod_id'] in params['ids'][0].split(',')]
            if 'wd' in params:
                word = params['wd'][0]
                if word == 'slow':
                    time.sleep(25)                      # 慢响应，测试竞态
                if word in ('slow', 'fast'):
                    rows = [dict(catalogue[0 if word == 'slow' else 1], vod_name=word + ' 测试结果')]
                else:
                    rows = [v for v in rows if word in v['vod_name']]
            if 'ids' not in params and 'wd' not in params and (ROOT / 'empty-home').exists():
                rows = []                               # 空态
            payload = json.dumps({
                'class': [{'type_id': '1', 'type_name': '电影'},
                          {'type_id': '2', 'type_name': '剧集'},
                          {'type_id': '3', 'type_name': '纪录片'}],
                'page': 1, 'pagecount': 1, 'limit': 20, 'total': len(rows), 'list': rows,
            }, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif query.path == '/sample.mp4' and self.headers.get('Range'):
            sample = ROOT / 'sample.mp4'
            if not sample.is_file():
                self.send_error(404, 'sample.mp4 missing; run fixture/make-assets.py')
                return
            size = sample.stat().st_size
            match = re.fullmatch(r'bytes=(\d*)-(\d*)', self.headers['Range'].strip())
            if not match or not any(match.groups()):
                self.send_error(400, 'Invalid single byte range')
                return
            start = int(match[1]) if match[1] else max(0, size - int(match[2]))
            end = int(match[2]) if match[1] and match[2] else size - 1
            end = min(end, size - 1)
            if start >= size or start > end:
                self.send_response(416)
                self.send_header('Content-Range', f'bytes */{size}')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            self.send_response(206)
            self.send_header('Content-Type', 'video/mp4')
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
            self.send_header('Content-Length', str(end - start + 1))
            self.end_headers()
            with sample.open('rb') as f:
                f.seek(start)
                self.wfile.write(f.read(end - start + 1))
        else:
            super().do_GET()


if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    print(f'fixture serving {ROOT} on 0.0.0.0:{PORT} (base={BASE})', flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
