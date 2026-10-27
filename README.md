# uLEAPP — LEAPP Installer/Updater

Idea by [@CyberMike81](https://github.com/CyberMike81).

One place to install, update and launch the LEAPP tools on Mac, Windows and Linux.
Every platform checks the tools’ official GitHub releases and chooses the matching
published package. There is no package-manager setup or update-method choice.

**Community Preview 0.3.14** is available for testing and feedback.

## Download

Get the matching package from the [Community Preview release](https://github.com/CyberMike81/uLEAPP/releases/tag/v0.3.14), extract it, and open uLEAPP. Keep its included notices.

| Platform | Download | Requirements |
| --- | --- | --- |
| Mac | `uLEAPP-0.3.14-macOS.zip` | macOS 13+; Apple silicon or Intel |
| Windows x64 | `uLEAPP-0.3.14-Windows-x64.zip` | 64-bit Intel/AMD Windows; runtime included |
| Windows ARM64 | `uLEAPP-0.3.14-Windows-ARM64.zip` | Windows 11 ARM; runtime included |
| Linux | `uLEAPP-0.3.14-Linux.tar.gz` | Python 3.10+ and Tk; x64 or ARM64 |

uLEAPP is ad hoc signed on Mac and unsigned on Windows. This preview is not
notarized. Publisher tools retain their own signing and platform requirements.

## Use it

- **Check for updates** compares installed versions with the publishers’ official releases.
- **Install** adds a missing tool; **Install missing apps** adds the available missing tools together.
- **Update apps** downloads and installs newer releases after you choose it. Close LEAPP apps first.
- **Launch** opens the latest successfully installed, selected copy. A failed update keeps the previous selection working.
- **Remove old installs** reviews eligible old managed copies before moving them to Trash or Recycle Bin. The current and one previous version are kept; unknown or changed folders and case data are preserved.

A row’s pill shows its status and version. Hover for check evidence. The row’s
**⋯** menu reveals the selected app or opens release notes. **Details** shows logs;
**Settings** contains the automatic uLEAPP update-check preference.

Existing apps are detected where supported. Installing an update leaves existing
Applications copies and external installer records alone; Launch in uLEAPP follows
its selected install. Tools are downloaded on demand, not bundled in uLEAPP.

uLEAPP can also notify you about a newer uLEAPP release. Its Download button opens
the matching download; replace uLEAPP yourself. Tool installation and uLEAPP’s own
update notification are separate operations.

## Tools

LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP, DLEAPP, GLEAPP, GLEAPP Map Downloader and
Batch LEAPP are supported where the publisher provides a compatible binary.

- Map Downloader has Mac, Windows and Linux builds for both architectures.
- Batch LEAPP has a Windows x64 GUI, used through emulation on Windows ARM. Apple silicon Macs get **Get latest** for the official GUI ZIP and manual installation. Its current Mac build is not notarized and reports version 0.0.0, so uLEAPP cannot verify that copy as current. No Batch binary is published for Intel Mac or Linux.
- GLEAPP uses its published x64 compatibility build on Windows ARM. Linux GLEAPP is currently x64-only.
- LAVA has separate freeware terms, shown before first installation. Its official 0.15.0 x64 Windows installer is selected on ARM because the native installer had missing files in testing; newer releases prefer native ARM.

Linux AppImages may require FUSE; publisher dependencies still apply. Launch
failures show the actual error and a log path.

## Mac permissions

Mac release installation verifies the published checksum, architecture, version,
Developer ID publisher team and Gatekeeper assessment, then applies quarantine.
If macOS blocks a required attribute, uLEAPP explains how to enable **App Management**
in System Settings. Permission is granted by you, not automatically by uLEAPP.

## Source and validation

- Mac: `macOS/Sources`; build with `bash macOS/tools/build.sh`.
- Windows: `Windows`; build with `Windows/tools/Build.ps1` and .NET 10 on Windows.
- Linux: `Linux`; run `python3 Linux/uleapp.py` or build its archive with `python3 Linux/package.py`.

See [VALIDATION.md](VALIDATION.md) for completed checks and hardware gaps.
uLEAPP is MIT licensed. Publisher software and artwork keep their own rights;
see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md), the platform READMEs and `licenses/`.
