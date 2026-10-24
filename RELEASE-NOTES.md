# uLEAPP 0.3.6 — Community Preview

- **Remove old installs** is now available on Windows and Linux as well as Mac. Review the list before moving eligible older copies to Recycle Bin/Trash. The current and one previous version are kept; nothing is cleaned up automatically.
- Windows and Linux now save an app-file inventory with new managed installs. Cleanup skips modified folders, added case/report files, symbolic links and older copies without an inventory. Current selections and contents are checked again after confirmation.
- Includes the Mac direct-install fallback when Homebrew is behind, Windows portable-package fallback, automatic uLEAPP update notifications and earlier fixes.

Download and extract the complete platform package. Mac requires macOS 13+ and Homebrew and supports Apple silicon/Intel. Windows x64/ARM64 packages include .NET. Mac is ad hoc signed without notarization; Windows builds are unsigned. Linux requires Python 3.10+ and Tk; cleanup uses desktop Trash on the same filesystem and preserves folders if Trash is unavailable.

SHA256SUMS-0.3.6.txt covers all downloads.
