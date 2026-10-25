# uLEAPP 0.3.13 — Community Preview

- Windows now creates Start menu shortcuts after successful app installs and updates, and refreshes them to open the current working version.
- “Create Start menu shortcuts” is enabled by default in Settings. Shortcuts are added for your account in the uLEAPP Start menu folder, with no administrator permission required.
- Apps stay in their existing install locations. Only shortcuts created by uLEAPP are replaced; custom and publisher shortcuts are preserved. Failed installs keep working shortcuts.
- Shortcut errors appear in Details without treating a successful app update as failed. Existing automatic-update preferences are preserved.

Mac and Linux are rebuilt at the same version; their functionality is unchanged.

Mac requires macOS 13+. Mac Batch installation remains manual; no Batch binaries are published for Intel Mac or Linux. uLEAPP Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk. Tool downloads remain subject to the publishers’ platform requirements.

SHA256SUMS-0.3.13.txt covers all downloads.
