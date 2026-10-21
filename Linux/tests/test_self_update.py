# SPDX-License-Identifier: MIT
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from self_update import select_update


def metadata(version='0.3.2'):
    name = f'uLEAPP-{version}-Linux.tar.gz'
    return {'tag_name': 'v' + version, 'draft': False, 'prerelease': False,
            'html_url': f'https://github.com/CyberMike81/uLEAPP/releases/tag/v{version}',
            'assets': [{'name': name, 'browser_download_url': f'https://github.com/CyberMike81/uLEAPP/releases/download/v{version}/{name}'}]}


class SelfUpdateTests(unittest.TestCase):
    def test_newer_release_selects_linux_package(self):
        update = select_update(metadata(), current='0.3.1')
        self.assertEqual(update['version'], '0.3.2')
        self.assertTrue(update['url'].endswith('uLEAPP-0.3.2-Linux.tar.gz'))

    def test_current_older_and_prerelease_are_hidden(self):
        for version in ('0.3.1', '0.2.2'):
            self.assertIsNone(select_update(metadata(version), current='0.3.1'))
        for flag in ('draft', 'prerelease'):
            data = metadata(); data[flag] = True
            self.assertIsNone(select_update(data, current='0.3.1'))

    def test_numeric_versions(self):
        self.assertIsNotNone(select_update(metadata('0.10.0'), current='0.9.0'))
        self.assertIsNone(select_update(metadata('0.9.0'), current='0.10.0'))

    def test_untrusted_missing_and_ambiguous_assets_are_hidden(self):
        data = metadata(); data['assets'][0]['browser_download_url'] = 'https://example.org/update'
        self.assertIsNone(select_update(data, current='0.3.1'))
        data = metadata(); data['html_url'] = 'https://example.org/notes'
        self.assertIsNone(select_update(data, current='0.3.1'))
        data = metadata(); data['assets'] *= 2
        self.assertIsNone(select_update(data, current='0.3.1'))
        data = metadata(); data['assets'] = []
        self.assertIsNone(select_update(data, current='0.3.1'))
