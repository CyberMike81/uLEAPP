# uLEAPP 0.3.12 — Community Preview

- One update method everywhere: uLEAPP now uses each tool’s official releases on Mac, Windows and Linux. No package-manager setup, toggle or fallback choice.
- Mac detects existing Applications copies and preserves them when installing an update. Earlier uLEAPP-selected installs keep working. Launch reads the selected record again and opens the latest successfully installed copy; a failed update keeps the working selection.
- Quieter rows combine status and version in one pill. Source text stays gray; orange marks available updates. Row menus reveal installed copies and open release notes.
- Settings folds away automatic uLEAPP checks; Details holds logs and the manual Mac Batch explanation. The footer shows the last check time and cleanup has a trash icon.
- Retired the Mac package-manager worker and password helper from the app. Download checksum, publisher, Gatekeeper, quarantine and safe-cleanup checks remain required.
- Includes the Windows installed/missing count fix and the official Batch LEAPP icon.

Mac requires macOS 13+. Mac Batch installation remains manual; no Batch binaries are published for Intel Mac or Linux. uLEAPP Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk. Tool downloads remain subject to the publishers’ platform requirements.

SHA256SUMS-0.3.12.txt covers all downloads.
