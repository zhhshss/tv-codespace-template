"""Exercise configuration, startup failure and repository reuse in temp directories."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ScriptTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, TV_WORKSPACES=str(self.root / 'workspaces'))
        for key in ['TV_DIR', 'TV_UI_DIR', 'MEDIA3_SOURCE_DIR', 'ANDROID_HOME',
                    'ANDROID_AVD_HOME', 'TV_RESULTS_DIR', 'TV_RUNTIME_DIR',
                    'GRADLE_USER_HOME', 'TV_FIXTURE_ROOT']:
            self.env.pop(key, None)
        self.env['TV_FIXTURE_ROOT'] = str(self.root / 'fixture')
        self.env.update(GIT_AUTHOR_NAME='Template test', GIT_AUTHOR_EMAIL='test@example.invalid',
                        GIT_COMMITTER_NAME='Template test', GIT_COMMITTER_EMAIL='test@example.invalid')

    def tearDown(self):
        self.temp.cleanup()

    def run_cmd(self, *args, **kwargs):
        return subprocess.run(args, env=self.env, text=True, capture_output=True,
                              check=True, **kwargs)

    def test_dotenv_from_another_directory(self):
        template = self.root / 'template'
        (template / 'scripts').mkdir(parents=True)
        shutil.copy(ROOT / 'scripts/env.sh', template / 'scripts/env.sh')
        (template / '.env').write_text('TV_FIXTURE_PORT=9123\nTV_DIR="/tmp/custom TV"\n')
        result = self.run_cmd('bash', '-euc',
                              'source "$1"; printf "%s|%s|%s" "$TV_FIXTURE_PORT" '
                              '"$MEDIA3_SOURCE_DIR" "$-"', 'bash',
                              str(template / 'scripts/env.sh'), cwd='/tmp')
        port, media, flags = result.stdout.split('|')
        self.assertEqual(port, '9123')
        self.assertEqual(media, '/tmp/custom TV/.media3')
        self.assertNotIn('a', flags)

    def test_emulator_failure_is_reported_without_boot_timeout(self):
        sdk = self.root / 'sdk'
        for path, text in [('emulator/emulator', 'echo "FATAL: no disk space"; exit 23'),
                           ('platform-tools/adb', 'exit 1')]:
            script = sdk / path
            script.parent.mkdir(parents=True, exist_ok=True)
            script.write_text('#!/bin/sh\n' + text + '\n')
            script.chmod(0o755)
        self.env.update(ANDROID_HOME=str(sdk), TV_EMULATOR_TIMEOUT='30')
        started = time.monotonic()
        result = subprocess.run(['bash', str(ROOT / 'scripts/start-emulator.sh')],
                                env=self.env, capture_output=True, text=True, timeout=12)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('FATAL: no disk space', result.stdout)
        self.assertLess(time.monotonic() - started, 12)

    def make_repo(self, name, branch, path, content):
        repo = self.root / name
        self.run_cmd('git', 'init', '-b', branch, str(repo))
        target = repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        self.run_cmd('git', '-C', str(repo), 'add', '.')
        self.run_cmd('git', '-C', str(repo), 'commit', '-m', 'fixture')
        return repo

    def test_repeated_bootstrap_preserves_existing_work(self):
        source = self.make_repo('source', 'base', '.github/media3-composite-settings.gradle.kts',
                                '// composite settings\n')
        self.run_cmd('git', '-C', str(source), 'branch', 'ui')
        media = self.make_repo('media', 'release', 'settings.gradle.kts', '// upstream\n')
        self.env.update(TV_REPO=str(source), TV_REF='base', TV_UI_REF='ui',
                        MEDIA_REPO=str(media), MEDIA_REF='release')
        step = str(ROOT / '.devcontainer/scripts/40-repos.sh')
        self.run_cmd('bash', step)
        workspaces = self.root / 'workspaces'
        tree = workspaces / 'TV-ui-redesign'
        settings = workspaces / 'TV/.media3/settings.gradle.kts'
        self.assertEqual(settings.read_text(), '// composite settings\n')
        settings.write_text('// local customization\n')
        (tree / 'unfinished.txt').write_text('preserve me')
        before = self.run_cmd('git', '-C', str(tree), 'rev-parse', 'HEAD').stdout
        fetch = self.run_cmd('git', '-C', str(workspaces / 'TV'), 'config', '--get-all',
                             'remote.origin.fetch').stdout
        self.run_cmd('bash', step)
        self.assertEqual(settings.read_text(), '// local customization\n')
        self.assertEqual((tree / 'unfinished.txt').read_text(), 'preserve me')
        self.assertEqual(before, self.run_cmd('git', '-C', str(tree), 'rev-parse', 'HEAD').stdout)
        self.assertEqual(fetch, self.run_cmd('git', '-C', str(workspaces / 'TV'),
                                           'config', '--get-all', 'remote.origin.fetch').stdout)


if __name__ == '__main__':
    unittest.main()
