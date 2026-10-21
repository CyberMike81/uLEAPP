#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build a portable source archive with notices and executable launcher."""
from pathlib import Path
import hashlib
import tarfile
from core import VERSION
root = Path(__file__).resolve().parents[1]
out = root / 'Linux/dist'
out.mkdir(exist_ok=True)
name = f'uLEAPP-{VERSION}-Linux'
archive = out / (name + '.tar.gz')
with tarfile.open(archive, 'w:gz') as tar:
    for filename in ['Linux/uleapp', 'Linux/uleapp.py', 'Linux/core.py', 'Linux/self_update.py', 'Linux/README.md']:
        tar.add(root/filename, arcname=name + '/' + Path(filename).name)
    for filename in ['LICENSE', 'THIRD-PARTY-NOTICES.md', 'licenses']:
        tar.add(root/filename, arcname=name + '/' + filename)
with tarfile.open(archive) as tar:
    assert tar.getmember(name + '/uleapp').mode & 0o111
    assert tar.getmember(name + '/core.py').size > 0
(out/(archive.name + '.sha256')).write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
print(archive)
