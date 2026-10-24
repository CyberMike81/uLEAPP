# uLEAPP 0.3.12 — Community Preview

- Quieter tool rows on Mac, Windows and Linux: one status pill carries the version, source information stays gray, and orange marks available updates.
- Mac **Return to Homebrew** moves into the row’s **⋯** menu. It stays disabled with a reason until both Homebrew’s installed version and its Applications copy have caught up. Installation-time safety checks still run.
- Added row menus for revealing the selected app and opening publisher release notes.
- **Settings** folds away automatic-check preferences (and optional Homebrew on Mac). **Details** keeps logs, with the Mac Batch signing/version limitations explained there. Batch’s manual Mac button now says **Get latest**.
- Footer shows the last check time, status hover help shows GitHub check evidence, and **Remove old installs** has a trash symbol. Official icons, primary actions and installation behavior remain in place.
- Includes the Windows installed/missing count fix from 0.3.11.

Mac requires macOS 13+; Homebrew is optional. Mac Batch installation remains manual; no Batch binaries are published for Intel Mac or Linux. uLEAPP Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk.

SHA256SUMS-0.3.12.txt covers all downloads.
