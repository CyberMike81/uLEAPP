# uLEAPP 0.3.9 — Community Preview

- Added GLEAPP Map Downloader: check, install, update, launch and old-install cleanup on Mac, Windows and Linux, selecting native Apple silicon/ARM64 or Intel/x64 packages.
- Added Batch LEAPP on Windows, selecting its GUI rather than the adjacent command-line executable. Windows ARM uses the official x64 build through emulation.
- Apple silicon Macs get a Batch LEAPP **Download** button for the exact official GUI ZIP. The current publisher build is not notarized and reports version 0.0.0, so installation stays manual and uLEAPP does not claim it is current or bypass macOS security checks. Existing Applications copies can be launched. No Batch package is offered on Intel Mac or Linux because none is published.
- Expanded the compact tool list to include companions. Companions use official GitHub downloads independently of the optional Homebrew setting.
- Existing permission guidance, verified Mac installation, update checks and manual cleanup remain in place.

Mac requires macOS 13+; Homebrew is optional. uLEAPP Mac builds are ad hoc signed; Windows builds are unsigned. Linux requires Python 3.10+ and Tk. Companion programs are downloaded on demand, not included in uLEAPP's packages.

SHA256SUMS-0.3.9.txt covers all downloads.
