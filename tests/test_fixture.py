"""HTTP integration checks, isolated from the user's fixture port and data."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]


class FixtureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.data = Path(cls.temp.name) / 'assets'
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        cls.base = f'http://127.0.0.1:{port}'
        env = dict(os.environ, TV_FIXTURE_ROOT=str(cls.data),
                   TV_FIXTURE_PORT=str(port), TV_FIXTURE_BASE=cls.base)
        cls.proc = subprocess.Popen(['python3', str(ROOT / 'fixture/server.py')],
                                    env=env, stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL)
        for _ in range(50):
            try:
                with urlopen(cls.base + '/config.json', timeout=1):
                    break
            except URLError:
                time.sleep(.1)
        else:
            cls.tearDownClass()
            raise AssertionError('fixture did not start')

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=5)
        cls.temp.cleanup()

    def request(self, path, byte_range=None):
        req = Request(self.base + path,
                      headers={'Range': byte_range} if byte_range else {})
        try:
            response = urlopen(req, timeout=3)
        except HTTPError as error:
            response = error
        with response:
            return response.status, response.headers, response.read()

    def test_config_and_search(self):
        _, _, body = self.request('/config.json')
        self.assertEqual(json.loads(body)['sites'][0]['api'], self.base + '/api')
        _, _, body = self.request('/api?wd=fast')
        self.assertEqual(json.loads(body)['list'][0]['vod_name'], 'fast 测试结果')

    def test_empty_home_keeps_details(self):
        marker = self.data / 'empty-home'
        marker.touch()
        try:
            self.assertEqual(json.loads(self.request('/api')[2])['list'], [])
            self.assertEqual(len(json.loads(self.request('/api?ids=1')[2])['list']), 1)
        finally:
            marker.unlink()

    def test_video_ranges(self):
        sample = self.data / 'sample.mp4'
        sample.write_bytes(b'0123456789')
        try:
            for header, expected in [('bytes=2-4', b'234'), ('bytes=7-', b'789'),
                                     ('bytes=-3', b'789'), ('bytes=8-50', b'89')]:
                status, headers, body = self.request('/sample.mp4', header)
                self.assertEqual(status, 206)
                self.assertEqual(body, expected)
                self.assertEqual(int(headers['Content-Length']), len(expected))
            for header in ['bytes=10-', 'bytes=6-2', 'bytes=-0']:
                self.assertEqual(self.request('/sample.mp4', header)[0], 416)
            self.assertEqual(self.request('/sample.mp4', 'garbage')[0], 400)
        finally:
            sample.unlink()
        self.assertEqual(self.request('/sample.mp4', 'bytes=0-9')[0], 404)
        self.assertEqual(self.request('/api')[0], 200)


if __name__ == '__main__':
    unittest.main()
