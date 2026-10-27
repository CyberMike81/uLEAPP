# SPDX-License-Identifier: MIT
"""Linux release discovery and per-user, versioned installations (Python 3.10+)."""
from dataclasses import dataclass
import hashlib
import fcntl
import json
import queue
import threading
import time
import os
from pathlib import Path
import platform
import posixpath
import re
import shutil
import subprocess
import tarfile
import tempfile
from launch_errors import Launch
from urllib.parse import quote, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

VERSION = '0.3.14'
MAX_BYTES = 2 * 1024**3

@dataclass(frozen=True)
class Tool:
    id: str
    name: str
    repo: str
    package_name: str = ''
    executable: str = ''

TOOLS = (Tool('lava', 'LAVA', 'leapps-org/LAVA-releases'),) + tuple(
    Tool(name.lower(), name, 'abrignoni/' + name)
    for name in ('ALEAPP', 'iLEAPP', 'RLEAPP', 'VLEAPP', 'DLEAPP', 'GLEAPP')) + (Tool('mapdownloader', 'Map Downloader', 'abrignoni/GLEAPP-MapDownloader', 'GLEAPP-MapDownloader', 'GLEAPP-MapDownloader'),)


def architecture():
    machine = platform.machine().lower()
    if machine in ('x86_64', 'amd64'): return 'x64'
    if machine in ('aarch64', 'arm64'): return 'arm64'
    raise ValueError('Only Linux x64 and ARM64 are supported.')


class GitHubRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urlparse(newurl)
        if (parsed.scheme != 'https' or parsed.hostname not in
                ('github.com', 'api.github.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com')
                or parsed.port not in (None, 443) or parsed.username or parsed.password):
            raise ValueError('Download redirected outside the official GitHub hosts.')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def request(url, headers=None):
    return build_opener(GitHubRedirects()).open(Request(url, headers={
        'User-Agent': 'uLEAPP/' + VERSION, 'Accept': 'application/vnd.github+json', **(headers or {})}), timeout=30)


@dataclass(frozen=True)
class Release:
    version: str
    name: str
    url: str
    digest: str
    size: int


def select_release(tool, data, arch):
    tag = data.get('tag_name', '')
    if not re.fullmatch(r'v?\d+(?:\.\d+){1,3}', tag) or data.get('draft') or data.get('prerelease'):
        raise ValueError('Only stable numeric releases are supported.')
    if arch not in ('x64', 'arm64'): raise ValueError('Unsupported architecture.')
    pattern = re.compile(re.escape(tool.package_name or tool.name) + r'-' + (r'v' if tool.id == 'mapdownloader' else '') + re.escape(tag.lstrip('v')) +
                         r'-linux[-_]' + arch + r'\.(?:AppImage|tar\.gz)', re.I)
    matches = [a for a in data['assets'] if pattern.fullmatch(a['name'])]
    if len(matches) != 1:
        raise ValueError(f'No unique Linux {arch} package is published for {tool.name}.')
    asset = matches[0]
    expected = f'https://github.com/{tool.repo}/releases/download/{tag}/{asset["name"]}'
    if asset['browser_download_url'] != expected:
        raise ValueError('Package does not point to the official release repository.')
    digest = asset.get('digest') or ''
    if not re.fullmatch(r'sha256:[0-9a-fA-F]{64}', digest):
        raise ValueError('The publisher has not provided a SHA-256 digest.')
    if not isinstance(asset['size'], int) or not 0 < asset['size'] <= MAX_BYTES:
        raise ValueError('Unexpected package size.')
    return Release(tag.lstrip('v'), asset['name'], expected, digest[7:].lower(), asset['size'])


class Cancelled(Exception):
    """The user stopped before an installation was committed."""


def check_cancel(cancel):
    if cancel is not None and cancel.is_set(): raise Cancelled('Stopped at your request.')


def stream_bytes(url, cancel=None, idle_timeout=60, metadata_headers=None, response_info=None):
    # A bounded reader queue keeps Stop responsive even during a blocking socket
    # read. Only this consumer writes files; a cancelled reader can never install.
    chunks = queue.Queue(maxsize=2)
    stopped = threading.Event()
    def send(value):
        while not stopped.is_set():
            try: chunks.put(value, timeout=0.1); return
            except queue.Full: pass
    def reader():
        try:
            with (request(url) if metadata_headers is None else request(url, metadata_headers)) as response:
                if response_info is not None:
                    response_info.update({key.lower(): value for key, value in getattr(response, 'headers', {}).items()})
                read = getattr(response, 'read1', response.read)
                while not stopped.is_set():
                    data = read(128 * 1024)
                    send(data)
                    if not data: break
        except Exception as error: send(error)
    check_cancel(cancel)
    threading.Thread(target=reader, daemon=True).start()
    last_data = time.monotonic()
    try:
        while True:
            check_cancel(cancel)
            if time.monotonic() - last_data >= idle_timeout:
                raise TimeoutError('No download data arrived for 60 seconds. Please try again.')
            try: item = chunks.get(timeout=min(0.1, idle_timeout))
            except queue.Empty: continue
            if isinstance(item, Exception): raise item
            if not item: break
            last_data = time.monotonic()
            yield item
    finally: stopped.set()


def latest(tool, arch, cancel=None):
    from release_metadata import fetch_json
    return select_release(tool, fetch_json(f'https://api.github.com/repos/{tool.repo}/releases/latest', cancel), arch)


def needs_update(installed, target):
    return tuple(map(int, installed.lstrip('v').split('.'))) < tuple(map(int, target.split('.')))


def download(release, destination, progress=lambda _: None, cancel=None):
    digest = hashlib.sha256()
    count = 0
    last_progress = 0.0
    with destination.open('xb') as output:
        for block in stream_bytes(release.url, cancel):
            count += len(block)
            if count > release.size: raise ValueError('Download exceeds its published size.')
            digest.update(block)
            output.write(block)
            now = time.monotonic()
            if now - last_progress >= 0.1 or count == release.size:
                progress(count / release.size)
                last_progress = now
    check_cancel(cancel)
    if count != release.size or digest.hexdigest() != release.digest:
        raise ValueError('Download checksum or size does not match. Nothing was installed.')


def extract_archive(package, destination, cancel=None):
    # Internal links in PyInstaller bundles are materialized as ordinary files.
    # No archive link is ever created on disk.
    with tarfile.open(package, 'r:gz') as archive:
        members = archive.getmembers()
        by_name = {posixpath.normpath(item.name): item for item in members}
        if len(by_name) != len(members) or len(members) > 100000:
            raise ValueError('Archive has duplicate paths or too many entries.')
        sources = []
        total = 0
        for item in members:
            path = Path(item.name)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Archive contains an unsafe path.')
            source = item
            if item.issym():
                target = posixpath.normpath(posixpath.join(posixpath.dirname(item.name), item.linkname))
                if target.startswith('/') or target == '..' or target.startswith('../'):
                    raise ValueError('Archive link leaves its package.')
                source = by_name.get(target)
                if source is None or not source.isfile():
                    raise ValueError('Archive link has no regular file target.')
            elif not (item.isfile() or item.isdir()):
                raise ValueError('Archive contains an unsafe file type.')
            total += source.size
            if total > 8 * 1024**3: raise ValueError('Extracted package is too large.')
            sources.append((item, source))
        for item, source in sources:
            check_cancel(cancel)
            target = destination / item.name
            if item.isdir(): target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(source) as content, target.open('xb') as output:
                    shutil.copyfileobj(content, output)
                target.chmod(0o755 if source.mode & 0o111 else 0o644)


class Store:
    def __init__(self, root=None):
        self.root = Path(root) if root else Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'uLEAPP'
        if not self.root.is_absolute(): raise ValueError('The installation folder must be absolute.')

    def tool_root(self, tool):
        path = self.root / 'apps' / tool.id
        for parent in (path, *path.parents):
            if parent.is_symlink(): raise ValueError('Installation folders must not be symbolic links.')
        return path

    def installed(self, tool):
        root = self.tool_root(tool)
        try: record = json.loads((root / 'current.json').read_text())
        except FileNotFoundError: return None
        if (not isinstance(record, dict) or not isinstance(record.get('path'), str)
                or not isinstance(record.get('version'), str)
                or not re.fullmatch(r'\d+(?:\.\d+){1,3}', record['version'])):
            raise ValueError(f'{tool.name} has an invalid installation record.')
        executable = root / record['path']
        if (Path(record['path']).is_absolute() or '..' in Path(record['path']).parts
                or not executable.resolve().is_relative_to(root.resolve())
                or executable.is_symlink() or not executable.is_file()):
            raise ValueError(f'{tool.name} has an invalid installation record.')
        return record

    def install(self, tool, release, progress=lambda _: None, cancel=None):
        root = self.tool_root(tool)
        root.mkdir(parents=True, exist_ok=True)
        lockpath = root / '.install.lock'
        descriptor = os.open(lockpath, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as lock:
            try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: raise ValueError('Another uLEAPP installation is running for this tool.')
            return self._install(tool, release, progress, cancel)

    def _install(self, tool, release, progress, cancel):
        root = self.tool_root(tool)
        root.mkdir(parents=True, exist_ok=True)
        destination = root / release.version
        if destination.exists(): raise ValueError('This version already exists; no files were replaced.')
        with tempfile.TemporaryDirectory(prefix='.staging-', dir=root) as temp:
            stage = Path(temp)
            package = stage / release.name
            if cancel is None: download(release, package, progress)
            else: download(release, package, progress, cancel)
            payload = stage / 'payload'
            payload.mkdir()
            if release.name.lower().endswith('.appimage'):
                executable = payload / release.name
                package.rename(executable)
                executable.chmod(0o755)
            else:
                extract_archive(package, payload, cancel)
                matches = [p for p in payload.rglob('*') if p.is_file() and
                           p.name.lower() == (tool.executable or tool.id).lower() and os.access(p, os.X_OK)]
                if len(matches) != 1: raise ValueError('Archive has no unique recognized executable.')
                executable = matches[0]
            relative = executable.relative_to(payload)
            from cleanup import write_manifest
            write_manifest(payload, tool, release.version, cancel)
            # Publish a complete version, then atomically select it. Keep older versions.
            check_cancel(cancel)
            payload.rename(destination)
            record = {'version': release.version, 'path': str(Path(release.version) / relative)}
            pending = stage / 'current.json'
            pending.write_text(json.dumps(record) + '\n')
            pending.replace(root / 'current.json')
        return record

    def launch(self, tool):
        record = self.installed(tool)
        if record is None: raise ValueError('Install this app first.')
        executable = self.tool_root(tool) / record['path']
        logs = self.root / 'logs'
        logs.mkdir(parents=True, exist_ok=True)
        descriptor, filename = tempfile.mkstemp(prefix=tool.id + '-', suffix='.log', dir=logs)
        log_path = Path(filename)
        with os.fdopen(descriptor, 'wb') as output:
            process = subprocess.Popen([str(executable)], cwd=executable.parent,
                                       stdin=subprocess.DEVNULL, stdout=output, stderr=output,
                                       start_new_session=True)
        return Launch(process, log_path)
