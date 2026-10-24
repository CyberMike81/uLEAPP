# uLEAPP 0.3.8 — Community Preview

- Homebrew is now optional on Mac. Without it, uLEAPP discovers existing apps and checks/downloads/installs the correct official Mac builds directly. **Use Homebrew when available** is a saved preference; `--no-homebrew` selects direct downloads for one run. Existing Homebrew-managed apps are not uninstalled.
- Mac App Management failures now explain the permission and offer **Open Settings** instead of a raw xattr error. Existing quarantine values are preserved on Launch rather than rewritten; new installations still receive quarantine before selection. Publisher and Gatekeeper checks remain required.
- Direct update requests recheck the selected version and skip apps already current.
- More compact windows on Mac, Windows and Linux show all seven tools and the main controls together, with sizing that respects the available screen space.
- Includes the audit fixes and manual cleanup on all platforms.

Mac requires macOS 13+; Homebrew is optional. Mac builds are ad hoc signed without notarization; Windows x64/ARM64 builds include .NET and are unsigned; Linux requires Python 3.10+ and Tk.

SHA256SUMS-0.3.8.txt covers all downloads.
