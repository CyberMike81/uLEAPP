# SPDX-License-Identifier: MIT
"""Conditional release metadata checks; never use stale data on network failure."""
import hashlib
import json
import os
from pathlib import Path
from urllib.error import HTTPError
import uuid
from core import stream_bytes

def fetch_json(url, cancel=None, cache_root=None):
    root = Path(cache_root) if cache_root is not None else Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache'))/'uLEAPP/release-metadata'
    file = root/(hashlib.sha256(url.encode()).hexdigest()+'.json')
    cache = None
    try:
        entry = json.loads(file.read_text())
        if entry['url'] == url and isinstance(entry['body'], str) and len(entry['body']) <= 8 * 1024**2:
            cache = entry
    except (OSError, ValueError, TypeError, KeyError): pass
    headers = {}
    if cache and isinstance(cache.get('etag'), str): headers['If-None-Match'] = cache['etag']
    response = {}
    data = bytearray()
    try:
        for chunk in stream_bytes(url, cancel, idle_timeout=15, metadata_headers=headers, response_info=response):
            data.extend(chunk)
            if len(data) > 8 * 1024**2: raise ValueError('Release metadata is too large.')
    except HTTPError as error:
        if error.code == 304 and cache:
            value = json.loads(cache['body'])
            if not isinstance(value, dict): raise ValueError('Invalid cached release metadata.')
            return value
        if error.code in (403, 429):
            remaining = error.headers.get('X-RateLimit-Remaining', 'unknown')
            reset = error.headers.get('X-RateLimit-Reset', 'unknown')
            raise ValueError(f'GitHub HTTP {error.code}. Requests remaining: {remaining}; reset (Unix time): {reset}. Wait before checking again.') from error
        raise
    value = json.loads(data)
    if not isinstance(value, dict): raise ValueError('Invalid release metadata.')
    temporary = root/('metadata.'+uuid.uuid4().hex+'.tmp')
    try:
        root.mkdir(parents=True, exist_ok=True)
        temporary.write_text(json.dumps({'url': url, 'etag': response.get('etag'), 'body': data.decode('utf-8')}))
        temporary.replace(file)
    except OSError: pass
    finally: temporary.unlink(missing_ok=True)
    return value
