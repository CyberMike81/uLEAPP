# uLEAPP 0.3.9 validation

Prepared October 24, 2026 for the Community Preview bug-fix release.

| Platform | Completed checks | Remaining manual coverage |
| --- | --- | --- |
| macOS 13+ | Universal Apple silicon/Intel build; native and Rosetta self-checks; archive extraction, resources, version and ad hoc signature verified; 101 Homebrew worker tests | Physical Intel Mac on macOS 13; clean installation; real password-helper flow and cancellation |
| Windows x64 | Fresh build and 168 packaged self-checks on a native GitHub x64 runner | Full manual installer/portable GUI flow on a user computer |
| Windows ARM64 | Fresh build and 168 packaged self-checks on a native Windows 11 ARM GitHub runner | Full manual installer/portable GUI flow on a user computer |
| Linux x64/ARM64 | 36 core tests; interface and extracted-package smoke checks on Ubuntu 24.04 runners; official GLEAPP archive checksum and layout checked | Actual LEAPP graphical launches on Linux hardware; WSL compatibility |

Windows release builds: https://github.com/CyberMike81/uLEAPP/actions/runs/40136221654

The October 21 bug fixes move Windows installation work off the UI thread,
throttle progress, add Windows/Linux download cancellation and stalled-transfer
timeouts, and cache/coalesce Mac icons and log output. Regression tests exercise
body cancellation after HTTP headers, blocked Linux reads, progress throttling,
cancelled-update cleanup, and split UTF-8/CRLF log records.

Stop leaves completed work in place. An official installer or Homebrew installation
already running finishes at a safe boundary. Mac read-only app discovery supports
Stop and a 60-second deadline; uLEAPP does not own Homebrew's download body and does
not claim immediate cancellation of its active installation command.

Windows builds are unsigned. The universal Mac app is ad hoc signed, without
Developer ID notarization. Linux is a portable Python/Tk distribution requiring
Python 3.10+ and Tk; GLEAPP is x64-only and requires glibc 2.39+; AppImages require
FUSE support. No real WSL compatibility claim is made.

Earlier audit findings and history remain in AUDIT-RESPONSE.md and
docs/AUDIT-2026-10-21.md. This release changes audited source; it does not inherit
an assertion that all source is unchanged from the earlier independent review.

Automatic uLEAPP checks run at startup and once per day while open. Selector tests
cover equal/older releases, numeric ordering, architecture-specific package names,
preview-flagged releases and unofficial links. The user opens downloads and release
notes in their browser; no self-installation or background package download occurs.

Linux launch-error coverage uses a real failing process to confirm captured stderr
and exit status, private per-launch logs and isolation from old errors. Empty,
missing, non-UTF-8 and oversized logs have explicit, bounded diagnostics. Successful
and still-running processes do not produce failure dialogs. The interface keeps
watching after the old one-shot startup window to catch later failures.

October 24 update compatibility checks:
- Mac: live GitHub comparisons detect ALEAPP 2026.4.4 and iLEAPP 2026.4.5 from their previous versions, and accept matching versions. A read-only Homebrew adapter reporting no updates plus the real packaged checker produces two pending statuses, with no installed-app changes. UI self-checks verify pending state and title.
- Windows: recorded October 24 publisher metadata for ALEAPP/iLEAPP is exercised on x64 and ARM64, including installer-managed to portable fallback, while older fixtures verify setup preference. The existing versioned portable installation path preserves older installations.

Mac direct-install fallback validation (October 24):
- Packaged self-checks cover both Mac package architectures, ambiguous/missing/unsafe assets, checksum/size failures, versioned publication, preservation of older apps, duplicate-version rejection, invalid records and cancellation.
- Worker tests cover selecting the recorded direct version, recognizing it without a Homebrew receipt, offering newer direct releases and preventing Homebrew from replacing a directly managed copy.
- The optional network integration downloaded official ALEAPP 2026.4.4, verified its image checksum, mounted it read-only, checked the app version, architecture and signature, copied it into an isolated temporary home, wrote the selected record and verified the copied signature. Real Applications folders, Homebrew receipts and user settings were unchanged.
- Universal Mac build and native/Intel self-checks passed. The full interactive direct-install flow remains to be exercised on a physical Intel Mac.

Manual Mac cleanup tests verify that the current and previous versions remain
ineligible, scans do not delete anything, unmarked folders and extra case files
are preserved, and changed app signatures are excluded. Cleanup is only invoked
by **Remove old installs**, with a review before the macOS Trash operation.

Windows/Linux manual cleanup validation:
- Three versioned fixture installs verify that scanning is read-only and keeps the current and previous versions.
- Added case data, modified binaries, unknown/linked folders, invalid manifests and forged paths are preserved. Review-time state and contents are rechecked before a move; cancellation keeps remaining folders.
- Windows native self-checks exercise IFileOperation recycling and verify the selected/current app and previous version remain.
- Linux tests verify Trash restore metadata and app contents, plus safe preservation on a failed move. GUI smoke checks verify the cleanup button is present and disabled in demo mode.

Mac self-checks now isolate direct-install discovery from real user records, so
the packaged tests remain deterministic after users install direct copies. Demo
mode also excludes these records. Normal app discovery continues to select the
recorded direct app and version.

Audit follow-up: native integration checks cover publisher team verification,
Gatekeeper assessment, quarantine, refusal of a Homebrew downgrade, and a verified
return in an isolated home. ETag/304 and quota-error paths use controlled responses.
Windows tests require a positive Recycle Bin destination callback; non-fixed
volume types are refused. Physical USB media, disabled-bin policy and quota edge
cases still need dedicated manual hardware coverage; no system policy is changed
by the automated tests. The Mac live Homebrew check dynamically selects a cask
whose decisions are still Homebrew-managed and explicitly skips the controlled
minimum-version assertion if none exists.

Completed native follow-up: a real ALEAPP direct-install test passed publisher
team verification, Gatekeeper assessment and explicit quarantine. The isolated
return-to-Homebrew test refused an older version, accepted a verified current
copy and removed only the selected record. Read-only live Homebrew evidence was
regenerated successfully with LAVA as the controlled minimum-version target;
all seven installed-version and final-status events were verified in both runs.

0.3.9 Mac coverage includes Homebrew-free discovery and all seven direct release
checks using injected release metadata, with no Homebrew executable or network.
Quarantine tests verify that an existing value is preserved. Native direct
installation still validates publisher identity, Gatekeeper and quarantine.
App Management messaging covers EPERM/EACCES; macOS permission grants remain a
user action in System Settings.

Compact layouts use shorter tool rows and screen-bounded initial windows on all
three platforms. Windows and Mac retain scrolling for smaller screens and enlarged
text; Linux sizes to its requested content within the available screen height.

Mac visual verification on the current display confirmed all seven installed
tools, six direct-copy/Homebrew return controls and all footer actions visible
without scrolling in the initial 1040 × 840 window.


0.3.9 companion coverage:
- Windows recorded official Batch v1.2.0 and Map Downloader v0.2.0 metadata covers both architectures, Batch x64 emulation fallback and GUI executable priority over the neighboring CLI.
- Linux recorded Map Downloader metadata covers both native architectures and duplicate rejection. A real official x64 archive passed digest verification, safe extraction, executable discovery and isolated installation recording on the build Mac; Linux execution is checked separately by platform CI smoke checks for uLEAPP.
- Mac selector tests cover both Map Downloader architectures, the Batch Apple silicon ZIP, refusal of Intel Batch selection and refusal of automatic Batch installation. The release download is manual for Batch; no Gatekeeper or publisher checks are disabled.
- Intel Mac omits Batch because the publisher has no Intel GUI package. Linux omits Batch because the publisher has no Linux binary package. Windows ARM uses the published x64 Batch GUI through operating-system emulation.

The real Mac Map Downloader installation passed in an isolated temporary home,
including publisher identity, Gatekeeper, architecture, bundle version, quarantine
and selected record. Real user applications were unchanged.

Final Mac visual check confirmed all nine tool rows and footer controls fit at
1040 × 840 while a real combined update check displayed its progress controls.
