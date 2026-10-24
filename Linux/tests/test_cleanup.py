# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from urllib.parse import unquote
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core import Store, TOOLS, Release, Cancelled
from cleanup import old_installs, trash_old_installs, OldInstall, MARKER


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name).resolve()
        self.store = Store(self.home/'state')
        self.tool = TOOLS[1]
        self.trash = self.home/'Trash'
        self.download = patch('core.download', side_effect=lambda release, destination, progress, *args: destination.write_bytes(b'app-' + release.version.encode()))
        self.download.start()
        self.addCleanup(self.download.stop)
        self.addCleanup(self.temp.cleanup)
        for version in ['1.2.3', '1.2.4', '1.2.5']:
            self.store.install(self.tool, Release(version, 'app.AppImage', '', '', 1))

    def test_review_is_read_only_and_keeps_current_and_previous(self):
        candidates = old_installs(self.store)
        self.assertEqual([item.version for item in candidates], ['1.2.3'])
        self.assertTrue(candidates[0].path.exists())
        self.assertEqual(self.store.installed(self.tool)['version'], '1.2.5')
        self.assertTrue((self.store.tool_root(self.tool)/'1.2.4').exists())

    def test_trash_has_restore_metadata_and_keeps_working_versions(self):
        candidate = old_installs(self.store)[0]
        moved = trash_old_installs(self.store, [candidate], trash=self.trash)
        self.assertEqual(moved, [candidate])
        self.assertFalse(candidate.path.exists())
        files = list((self.trash/'files').iterdir())
        self.assertEqual(len(files), 1)
        self.assertTrue((files[0]/'app.AppImage').exists())
        info = next((self.trash/'info').iterdir()).read_text()
        self.assertIn('Path=' + str(candidate.path), unquote(info))
        self.assertIn('DeletionDate=', info)
        self.assertEqual(self.store.installed(self.tool)['version'], '1.2.5')
        self.assertTrue((self.store.tool_root(self.tool)/'1.2.4/app.AppImage').exists())

    def test_added_case_files_and_changed_binaries_are_preserved(self):
        folder = self.store.tool_root(self.tool)/'1.2.3'
        extra = folder/'case.txt'; extra.write_text('private case')
        self.assertEqual(old_installs(self.store), [])
        extra.unlink()
        (folder/'app.AppImage').write_bytes(b'changed app')
        self.assertEqual(old_installs(self.store), [])
        self.assertTrue(folder.exists())

    def test_revalidates_modified_contents_after_review(self):
        candidate = old_installs(self.store)[0]
        (candidate.path/'report.json').write_text('{}')
        self.assertEqual(trash_old_installs(self.store, [candidate], trash=self.trash), [])
        self.assertTrue(candidate.path.exists())

    def test_revalidates_current_selection_and_rejects_forged_path(self):
        candidate = old_installs(self.store)[0]
        record = {'version': '1.2.3', 'path': '1.2.3/app.AppImage'}
        (self.store.tool_root(self.tool)/'current.json').write_text(json.dumps(record))
        self.assertEqual(trash_old_installs(self.store, [candidate], trash=self.trash), [])
        forged = OldInstall(self.tool.id, candidate.label, candidate.version, self.home)
        self.assertEqual(trash_old_installs(self.store, [forged], trash=self.trash), [])
        self.assertTrue(self.home.exists())

    def test_unmarked_and_linked_folders_are_not_eligible(self):
        candidate = old_installs(self.store)[0]
        (candidate.path/MARKER).unlink()
        self.assertEqual(old_installs(self.store), [])
        (self.store.tool_root(self.tool)/'1.0.0').symlink_to(self.home, target_is_directory=True)
        self.assertEqual(old_installs(self.store), [])

    def test_cancelled_cleanup_never_moves_anything(self):
        candidate = old_installs(self.store)[0]
        cancel = threading.Event(); cancel.set()
        with self.assertRaises(Cancelled):
            trash_old_installs(self.store, [candidate], cancel=cancel, trash=self.trash)
        self.assertTrue(candidate.path.exists())

    def test_trash_failure_preserves_install_and_removes_only_own_metadata(self):
        candidate = old_installs(self.store)[0]
        with patch('pathlib.Path.rename', side_effect=OSError('drive unavailable')):
            with self.assertRaises(OSError):
                trash_old_installs(self.store, [candidate], trash=self.trash)
        self.assertTrue(candidate.path.exists())
        self.assertEqual(list((self.trash/'info').iterdir()), [])

    def test_changed_marker_is_preserved(self):
        candidate = old_installs(self.store)[0]
        data = json.loads((candidate.path/MARKER).read_text());data['tool'] = 'unknown'
        (candidate.path/MARKER).write_text(json.dumps(data))
        self.assertEqual(old_installs(self.store), [])
