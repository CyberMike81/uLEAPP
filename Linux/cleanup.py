# SPDX-License-Identifier: MIT
"""Reviewed, recoverable cleanup of unchanged uLEAPP-owned app versions."""
from dataclasses import dataclass
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.parse import quote
import uuid
from core import TOOLS, check_cancel

MARKER = '.uleapp-install.json'


def snapshot(root, cancel=None):
    entries = {}
    for path in sorted(root.rglob('*')):
        check_cancel(cancel)
        relative = path.relative_to(root).as_posix()
        if relative == MARKER:
            continue
        if path.is_symlink():
            raise ValueError('An app folder contains a symbolic link; it was preserved.')
        if path.is_dir():
            entries[relative] = 'directory'
        elif path.is_file():
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                while block := stream.read(1024 * 1024):
                    check_cancel(cancel)
                    digest.update(block)
            entries[relative] = digest.hexdigest()
        else:
            raise ValueError('An app folder contains a special file; it was preserved.')
    return entries


def write_manifest(folder, tool, version, cancel=None):
    data = {'schema': 1, 'tool': tool.id, 'version': version, 'files': snapshot(folder, cancel)}
    with (folder / MARKER).open('x') as stream:
        json.dump(data, stream)
        stream.write('\n')


@dataclass(frozen=True)
class OldInstall:
    tool_id: str
    label: str
    version: str
    path: Path


def old_installs(store, tools=TOOLS, cancel=None):
    result = []
    for tool in tools:
        check_cancel(cancel)
        current = store.installed(tool)
        if current is None:
            continue
        root = store.tool_root(tool)
        versions = []
        for folder in root.iterdir():
            check_cancel(cancel)
            if (folder.is_symlink() or not folder.is_dir() or
                    not re.fullmatch(r'\d+(?:\.\d+){1,3}', folder.name)):
                continue
            marker = folder / MARKER
            try:
                if marker.is_symlink():
                    continue
                data = json.loads(marker.read_text())
                if (data.get('schema') != 1 or data.get('tool') != tool.id or
                        data.get('version') != folder.name or not isinstance(data.get('files'), dict) or not data['files']):
                    continue
                versions.append((folder, data['files']))
            except (OSError, ValueError, AttributeError):
                continue
        versions.sort(key=lambda item: tuple(map(int, item[0].name.split('.'))), reverse=True)
        previous = next((folder.name for folder, _ in versions if folder.name != current['version']), None)
        for folder, expected in versions:
            if folder.name in (current['version'], previous):
                continue
            try:
                if snapshot(folder, cancel) == expected:
                    result.append(OldInstall(tool.id, tool.name + ' ' + folder.name, folder.name, folder))
            except (OSError, ValueError):
                continue
    return result


def _trash(folder, trash):
    # Freedesktop home Trash. Cross-device moves fail safely rather than deleting.
    trash = Path(trash)
    if not trash.is_absolute():
        raise ValueError('Trash must use an absolute path.')
    for parent in (trash, *trash.parents):
        if parent.is_symlink():
            raise ValueError('Trash folders must not be symbolic links.')
    files, info = trash / 'files', trash / 'info'
    for path in (files, info):
        if path.is_symlink():
            raise ValueError('Trash folders must not be symbolic links.')
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if folder.stat().st_dev != files.stat().st_dev:
        raise ValueError('Trash is not available on this drive. The old installation was preserved.')
    name = folder.name + '-uLEAPP-' + uuid.uuid4().hex
    details = info / (name + '.trashinfo')
    data = '[Trash Info]\nPath=' + quote(str(folder.resolve()), safe='/') + '\nDeletionDate=' + datetime.now().strftime('%Y-%m-%dT%H:%M:%S') + '\n'
    descriptor = os.open(details, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(data)
    try:
        folder.rename(files / name)
    except Exception:
        details.unlink()
        raise


def trash_old_installs(store, selected, cancel=None, progress=lambda _: None, trash=None):
    if trash is None:
        trash = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'Trash'
    moved = []
    for candidate in selected:
        check_cancel(cancel)
        tool = next((tool for tool in TOOLS if tool.id == candidate.tool_id), None)
        if tool is None:
            continue
        root = store.tool_root(tool)
        descriptor = os.open(root / '.install.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise ValueError('An installation is running for ' + tool.name + '. Try cleanup again afterward.')
            # The selection and contents can change while the review is open.
            if candidate not in old_installs(store, [tool], cancel):
                continue
            check_cancel(cancel)
            _trash(candidate.path, trash)
            moved.append(candidate)
            progress(candidate)
    return moved
