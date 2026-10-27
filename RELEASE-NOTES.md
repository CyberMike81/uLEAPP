# uLEAPP 0.3.14 — Community Preview

- Windows portable updates now update the selected app in its existing folder, keeping its executable path and refreshing its uLEAPP Start menu shortcut. No separate AppData copy is installed.
- First-time portable installs ask you to choose an empty app folder. Cancelling skips that app.
- Added “Use existing installation…” to each Windows tool's row menu so you can select an existing copy, including one in Program Files.
- Updates prepare a replacement beside the app and keep the original folder as a rollback copy. User files are preserved, and an interrupted swap can recover at the next startup.
- Restricted locations explain the required Windows permissions instead of silently installing elsewhere. Official full installers retain their own setup flow.

Mac and Linux are rebuilt at the same version; their functionality is unchanged.

Rollback copies need disk space and are retained for manual review because they may contain case files. Program Files updates may require reopening uLEAPP as administrator. Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk.

SHA256SUMS-0.3.14.txt covers all downloads.
