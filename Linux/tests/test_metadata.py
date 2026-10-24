# SPDX-License-Identifier: MIT
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from email.message import Message
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from release_metadata import fetch_json
from preferences import load_automatic, save_automatic

class MetadataTests(unittest.TestCase):
    def test_conditional_request_uses_only_confirmed_cached_response(self):
        headers = Message(); headers['ETag'] = '"one"'
        class Response(io.BytesIO): pass
        first = Response(b'{"tag_name":"v1.2.3"}'); first.headers = headers
        seen = []
        def request(url, extra):
            seen.append(extra)
            if len(seen) == 1: return first
            raise HTTPError(url,304,'unchanged',headers,None)
        with tempfile.TemporaryDirectory() as temp, patch('core.request',side_effect=request):
            self.assertEqual(fetch_json('https://api.github.com/test',cache_root=temp)['tag_name'],'v1.2.3')
            self.assertEqual(fetch_json('https://api.github.com/test',cache_root=temp)['tag_name'],'v1.2.3')
        self.assertEqual(seen,[{}, {'If-None-Match':'"one"'}])

    def test_rate_limit_details_and_no_offline_success(self):
        headers = Message(); headers['X-RateLimit-Remaining']='0'; headers['X-RateLimit-Reset']='12345'
        with tempfile.TemporaryDirectory() as temp, patch('core.request',side_effect=HTTPError('url',403,'limit',headers,None)):
            with self.assertRaisesRegex(ValueError,'Requests remaining: 0; reset.*12345'):
                fetch_json('https://api.github.com/test',cache_root=temp)
        with tempfile.TemporaryDirectory() as temp, patch('core.request',side_effect=OSError('offline')):
            with self.assertRaises(OSError): fetch_json('https://api.github.com/test',cache_root=temp)

    def test_update_preference_persists_and_corrupt_file_is_quiet(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            self.assertTrue(load_automatic(root))
            save_automatic(root,False); self.assertFalse(load_automatic(root))
            save_automatic(root,True); self.assertTrue(load_automatic(root))
            (root/'preferences.json').write_text('broken')
            self.assertFalse(load_automatic(root))
