# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import uuid

def load_automatic(root):
    try:
        value = json.loads((root/'preferences.json').read_text())['automatic_update_checks']
        return value if isinstance(value, bool) else False
    except FileNotFoundError: return True
    except (OSError, ValueError, KeyError, TypeError): return False

def save_automatic(root, enabled):
    root.mkdir(parents=True, exist_ok=True)
    temporary = root/('preferences.' + uuid.uuid4().hex + '.tmp')
    try:
        temporary.write_text(json.dumps({'automatic_update_checks': bool(enabled)})+'\n')
        temporary.replace(root/'preferences.json')
    finally: temporary.unlink(missing_ok=True)
