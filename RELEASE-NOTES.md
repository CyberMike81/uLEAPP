# uLEAPP 0.3.4 — Community Preview

- Mac checks now verify GitHub releases before reporting an app as up to date. When Homebrew is behind, the app shows **Homebrew update pending** with a **Get latest** link to the publisher. Failed GitHub checks show **Needs attention**.
- Windows can update installer-managed ALEAPP and iLEAPP copies using the official portable ZIP when the publisher no longer provides setup. The new version goes in the selected portable-app folder, with the older installation preserved. Available setup installers remain preferred.
- Includes all previous fixes and automatic uLEAPP update notifications.

Download and extract the complete platform package. Mac supports Apple silicon and Intel, requires macOS 13+ and Homebrew, and is ad hoc signed without notarization. Windows x64/ARM64 packages include .NET and are unsigned. Linux requires Python 3.10+ and Tk.

SHA256SUMS-0.3.4.txt covers the downloads.
