# uLEAPP 0.3.3 validation

Prepared October 22, 2026 for the Community Preview bug-fix release.

| Platform | Completed checks | Remaining manual coverage |
| --- | --- | --- |
| macOS 13+ | Universal Apple silicon/Intel build; native and Rosetta self-checks; archive extraction, resources, version and ad hoc signature verified; 79 Homebrew worker tests | Physical Intel Mac on macOS 13; clean installation; real password-helper flow and cancellation |
| Windows x64 | Fresh build and 128 packaged self-checks on a native GitHub x64 runner | Full manual installer/portable GUI flow on a user computer |
| Windows ARM64 | Fresh build and 128 packaged self-checks on a native Windows 11 ARM GitHub runner | Full manual installer/portable GUI flow on a user computer |
| Linux x64/ARM64 | 23 core tests; interface and extracted-package smoke checks on Ubuntu 24.04 runners; official GLEAPP archive checksum and layout checked | Actual LEAPP graphical launches on Linux hardware; WSL compatibility |

Windows release builds: https://github.com/CyberMike81/uLEAPP/actions/runs/39794195777

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
