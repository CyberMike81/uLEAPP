# SPDX-License-Identifier: MIT
"""Bounded, launch-specific diagnostics. Does not infer missing dependencies."""
from dataclasses import dataclass
from pathlib import Path
import subprocess


@dataclass
class Launch:
    process: subprocess.Popen
    log_path: Path

    def poll(self):
        return self.process.poll()

    def failure_message(self, limit=8192):
        code = self.poll()
        if code is None or code == 0: return None
        try:
            with self.log_path.open('rb') as stream:
                stream.seek(0, 2)
                size = stream.tell()
                stream.seek(max(0, size - limit))
                raw = stream.read(limit)
            detail = raw.decode('utf-8', errors='replace').replace('\x00', '').strip()
            if not detail: detail = 'No error output was captured for this launch.'
            elif size > limit: detail = '[Last portion of the launch log]\n' + detail
        except OSError as error:
            detail = 'Could not read the launch log: ' + str(error)
        status = f'exit code {code}' if code > 0 else f'signal {-code}'
        return f'The app exited with {status}.\n\n{detail}\n\nLaunch log: {self.log_path}'
