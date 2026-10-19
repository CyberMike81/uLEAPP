# SPDX-License-Identifier: MIT
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core import TOOLS, Release, Store, download, extract_archive, needs_update, select_release


def metadata(tool=TOOLS[1], arch='x64', suffix='AppImage'):
    name = f'{tool.name}-1.2.3-linux-{arch}.{suffix}'
    return {'tag_name': 'v1.2.3', 'assets': [{'name': name,
        'browser_download_url': f'https://github.com/{tool.repo}/releases/download/v1.2.3/{name}',
        'digest': 'sha256:' + 'a' * 64, 'size': 100}]}


class CoreTests(unittest.TestCase):
    def test_all_appimage_catalog_entries_and_architectures(self):
        for tool in TOOLS[:-1]:
            for arch in ('x64', 'arm64'):
                data = metadata(tool, arch)
                if tool.id == 'lava':
                    asset = data['assets'][0]
                    asset['name'] = asset['name'].replace('linux-', 'Linux_')
                    asset['browser_download_url'] = asset['browser_download_url'].replace('linux-', 'Linux_')
                self.assertEqual(select_release(tool, data, arch).version, '1.2.3')

    def test_gleapp_native_only(self):
        tool = TOOLS[-1]
        self.assertTrue(select_release(tool, metadata(tool, suffix='tar.gz'), 'x64').name.endswith('.tar.gz'))
        with self.assertRaises(ValueError): select_release(tool, metadata(tool, suffix='tar.gz'), 'arm64')

    def test_reject_untrusted_release_metadata(self):
        tool = TOOLS[1]
        for field, value in [('browser_download_url', 'https://example.org/package'), ('digest', None), ('size', 0)]:
            data = metadata(); data['assets'][0][field] = value
            with self.assertRaises(ValueError): select_release(tool, data, 'x64')
        for flag in ('draft', 'prerelease'):
            data = metadata(); data[flag] = True
            with self.assertRaises(ValueError): select_release(tool, data, 'x64')
        data = metadata(); data['assets'] *= 2
        with self.assertRaises(ValueError): select_release(tool, data, 'x64')

    def test_newer_installed_version_is_not_downgraded(self):
        self.assertFalse(needs_update('2026.5.4', '2026.4.3'))
        self.assertFalse(needs_update('v1.2.3', '1.2.3'))
        self.assertTrue(needs_update('1.2.3', '1.2.4'))

    def test_download_requires_matching_size_and_digest(self):
        data = b'official package'
        with tempfile.TemporaryDirectory() as temp:
            for index, (size, digest) in enumerate([(len(data), '0'*64), (len(data)+1, hashlib.sha256(data).hexdigest()), (1, hashlib.sha256(data).hexdigest())]):
                release = Release('1.2.3', 'test', 'unused', digest, size)
                with patch('core.request', return_value=io.BytesIO(data)):
                    with self.assertRaises(ValueError): download(release, Path(temp).resolve()/str(index))

    def test_archive_rejects_traversal_and_links(self):
        with tempfile.TemporaryDirectory() as temp:
            for index, (name, kind) in enumerate([('../escape', tarfile.REGTYPE), ('/escape', tarfile.REGTYPE), ('link', tarfile.SYMTYPE), ('hardlink', tarfile.LNKTYPE)]):
                package = Path(temp).resolve()/f'{index}.tar.gz'
                with tarfile.open(package, 'w:gz') as tar:
                    info = tarfile.TarInfo(name); info.type = kind; info.linkname = '../escape'; tar.addfile(info)
                with self.assertRaises(ValueError): extract_archive(package, Path(temp).resolve()/'out')

    def test_install_update_failure_preserves_previous_app_and_case(self):
        with tempfile.TemporaryDirectory() as temp:
            store = Store(Path(temp).resolve()); tool = TOOLS[1]
            data = b'#!/bin/sh\nexit 0\n'
            def fetch(_release, destination, _progress): destination.write_bytes(data)
            release = Release('1.2.3', 'test.AppImage', 'unused', '', len(data))
            with patch('core.download', side_effect=fetch): record = store.install(tool, release)
            executable = store.tool_root(tool)/record['path']
            self.assertTrue(executable.stat().st_mode & 0o111)
            case = executable.parent/'case.txt'; case.write_text('evidence')
            with patch('core.download', side_effect=ValueError('checksum')):
                with self.assertRaises(ValueError): store.install(tool, Release('1.2.4', 'test.AppImage', '', '', 1))
            self.assertEqual(store.installed(tool), record)
            self.assertEqual(case.read_text(), 'evidence')
            with patch('core.download', side_effect=fetch): store.install(tool, Release('1.2.4', 'test.AppImage', '', '', len(data)))
            self.assertEqual(store.installed(tool)['version'], '1.2.4')
            self.assertEqual(case.read_text(), 'evidence')
            with patch('core.subprocess.Popen') as spawn:
                store.launch(tool)
                self.assertEqual(spawn.call_args.args[0], [str(store.tool_root(tool)/'1.2.4/test.AppImage')])

    def test_internal_library_link_is_materialized(self):
        with tempfile.TemporaryDirectory() as temp:
            package = Path(temp).resolve()/'test.tar.gz'
            with tarfile.open(package, 'w:gz') as tar:
                info = tarfile.TarInfo('app/libs/lib.so'); info.size = 4
                tar.addfile(info, io.BytesIO(b'data'))
                link = tarfile.TarInfo('app/lib.so'); link.type = tarfile.SYMTYPE; link.linkname = 'libs/lib.so'
                tar.addfile(link)
            out = Path(temp).resolve()/'out'
            extract_archive(package, out)
            self.assertEqual((out/'app/lib.so').read_bytes(), b'data')
            self.assertFalse((out/'app/lib.so').is_symlink())

    def test_concurrent_install_is_rejected(self):
        import fcntl
        with tempfile.TemporaryDirectory() as temp:
            store = Store(Path(temp).resolve()); tool = TOOLS[1]
            root = store.tool_root(tool); root.mkdir(parents=True)
            with (root/'.install.lock').open('w') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaisesRegex(ValueError, 'Another uLEAPP'):
                    store.install(tool, Release('1.2.3','test.AppImage','','',1))

    def test_tar_install_finds_nested_executable(self):
        with tempfile.TemporaryDirectory() as temp:
            def fetch(_release, destination, _progress):
                with tarfile.open(destination, 'w:gz') as tar:
                    info=tarfile.TarInfo('GLEAPP/GLEAPP'); info.mode=0o755; info.size=4
                    tar.addfile(info, io.BytesIO(b'test'))
            store = Store(Path(temp).resolve())
            with patch('core.download', side_effect=fetch):
                record = store.install(TOOLS[-1], Release('1.2.3','test.tar.gz','','',1))
            self.assertEqual(record['path'], '1.2.3/GLEAPP/GLEAPP')

    def test_store_rejects_symlink_root_and_escaped_record(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            (root/'link').symlink_to(root, target_is_directory=True)
            with self.assertRaises(ValueError): Store(root/'link').installed(TOOLS[1])
            store = Store(root/'data'); toolroot = store.tool_root(TOOLS[1]); toolroot.mkdir(parents=True)
            (toolroot/'current.json').write_text(json.dumps({'version':'1.0', 'path':'../../outside'}))
            with self.assertRaises(ValueError): store.installed(TOOLS[1])


if __name__ == '__main__': unittest.main()
