# SPDX-License-Identifier: MIT
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core import Store, TOOLS
from launch_errors import Launch


class LaunchErrorTests(unittest.TestCase):
    def test_actual_stderr_and_exit_code_with_isolated_logs(self):
        with tempfile.TemporaryDirectory() as temporary:
            store = Store(Path(temporary).resolve())
            tool = TOOLS[-1]
            directory = store.tool_root(tool)/'1.0.0'
            directory.mkdir(parents=True)
            executable = directory/'GLEAPP'
            executable.write_text('#!/bin/sh\nprintf "Unable to load libexample.so\\n" >&2\nexit 7\n')
            executable.chmod(0o755)
            (directory.parent/'current.json').write_text(json.dumps({'version':'1.0.0','path':'1.0.0/GLEAPP'}))
            (store.root/'logs').mkdir()
            (store.root/'logs/gleapp.log').write_text('OLD unrelated FUSE error\n')
            first = store.launch(tool)
            first.process.wait(timeout=5)
            second = store.launch(tool)
            second.process.wait(timeout=5)
            message = first.failure_message()
            self.assertIn('exit code 7', message)
            self.assertIn('Unable to load libexample.so', message)
            self.assertNotIn('FUSE', message)
            self.assertNotEqual(first.log_path, second.log_path)
            self.assertEqual(first.log_path.stat().st_mode & 0o777, 0o600)

    def test_success_or_running_process_has_no_error(self):
        for code in (None, 0):
            self.assertIsNone(Launch(Mock(poll=lambda: code), Path('/nonexistent')).failure_message())

    def test_empty_missing_and_non_utf8_logs(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)/'error.log'
            launch = Launch(Mock(poll=lambda: 1), path)
            self.assertIn('Could not read', launch.failure_message())
            path.write_bytes(b'')
            self.assertIn('No error output was captured', launch.failure_message())
            path.write_bytes(b'failure: \xff\x00')
            self.assertIn('failure:', launch.failure_message())
            self.assertNotIn('\x00', launch.failure_message())

    def test_log_tail_is_bounded_and_reports_signal(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)/'error.log'
            path.write_bytes(b'x'*100000 + b'\nactual failure\n')
            message = Launch(Mock(poll=lambda: -11), path).failure_message(limit=512)
            self.assertIn('signal 11', message)
            self.assertIn('actual failure', message)
            self.assertIn('Last portion', message)
            self.assertLess(len(message), 1000)
