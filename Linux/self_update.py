# SPDX-License-Identifier: MIT
"""Optional uLEAPP update notification; never installs or downloads a package."""
import json
import re
from core import VERSION, stream_bytes

REPOSITORY = 'CyberMike81/uLEAPP'


def select_update(data, current=VERSION):
    tag = data.get('tag_name', '')
    if data.get('draft') or data.get('prerelease') or not re.fullmatch(r'v?\d+\.\d+\.\d+', tag):
        return None
    version = tag.removeprefix('v')
    if tuple(map(int, version.split('.'))) <= tuple(map(int, current.split('.'))):
        return None
    page = f'https://github.com/{REPOSITORY}/releases/tag/{tag}'
    name = f'uLEAPP-{version}-Linux.tar.gz'
    url = f'https://github.com/{REPOSITORY}/releases/download/{tag}/{name}'
    assets = [a for a in data.get('assets', []) if a.get('name') == name and a.get('browser_download_url') == url]
    if len(assets) != 1 or data.get('html_url') != page:
        return None
    return {'version': version, 'url': url, 'page': page}


def check_update():
    data = bytearray()
    for chunk in stream_bytes(f'https://api.github.com/repos/{REPOSITORY}/releases/latest', idle_timeout=15):
        data.extend(chunk)
        if len(data) > 1024**2: raise ValueError('Update metadata is too large.')
    return select_update(json.loads(data))
