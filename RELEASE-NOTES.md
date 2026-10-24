# uLEAPP 0.3.5 — Community Preview

- Mac can now install the publisher’s latest build directly when Homebrew is behind. **Update** downloads the correct Apple silicon/Intel disk image, checks its SHA-256, version, architecture and signature, and installs it in a versioned folder under `~/Applications/uLEAPP`. **Launch** opens that selected copy.
- Direct installs are tracked separately so future checks use the version actually selected by uLEAPP. Older copies and Homebrew receipts are preserved. Download progress, Stop and errors are shown in the app.
- **Update apps** uses this fallback for releases still pending after the Homebrew operation. Merely checking for updates does not download or install apps.
- **Remove old installs** offers manual cleanup of older direct Mac copies. It keeps the current version and one previous version, shows the proposed list, and moves eligible older copies to Trash. Homebrew copies, untracked folders and changed apps are preserved. Nothing is cleaned up automatically.
- Includes the Windows portable-package fallback and all previous fixes.

Mac requires macOS 13+ and Homebrew. The Mac build is ad hoc signed without notarization; Windows x64/ARM64 builds include .NET and are unsigned. Linux requires Python 3.10+ and Tk. Download and extract the complete platform package.

SHA256SUMS-0.3.5.txt covers the downloads.
