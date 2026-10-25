# uLEAPP 0.3.13 validation

Prepared October 25, 2026. This release adds Windows Start menu shortcuts; Mac
and Linux changes are version metadata only. The independent 0.3.12 audit is
historical evidence for the unchanged paths, not an audit of this new feature.

Windows native x64 and ARM64 release builds run 196 packaged self-checks,
including real WPF properties and real Windows shell shortcut creation in isolated
temporary directories. Shortcut regressions cover default-on settings, migration
from older preferences, preserving automatic-check and shortcut opt-outs, custom
app locations and working directories, replacing an owned link without duplicates,
retaining a working shortcut for a missing target, preserving a user-created
shortcut, and leaving app files in place. No tests write to the real Start menu.

Shortcut integration runs only after a successful install or when Update apps
finds the selected version is already current. It is skipped for checks, demos,
opt-out and failed installations. A separate warning preserves the successful app
result when the Start menu is inaccessible. Links use the current user's Programs
folder, an ownership marker, and a staged file before replacement. Reparse-point
locations are refused. No elevation, desktop shortcut, relocation, or publisher
shortcut modification is introduced. Disabling the setting retains existing links.

Native Windows build evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40220934046
Linux x64/ARM64 test and package evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40220935790

Mac verification includes a universal arm64/x86_64 build, native and Rosetta
self-checks, strict signature verification and resource/version smoke checks.
Linux runs 36 core tests and native CI desktop/extracted-package smoke tests.
Published package digests, executable versions and architectures are checked
before publication; public release digests are compared to local packages.

Remaining manual coverage: actual Windows Start menu search and clicking shortcuts
on user hardware, folder/policy restrictions, full publisher installer GUIs,
Windows ARM x64 emulation, physical Intel Mac/macOS 13, actual Mac App Management
denial, and Linux publisher GUI/WSL behavior. Existing Batch artwork permission
remains unresolved; no new license grant is asserted. Mac builds are ad hoc signed
and not notarized; Windows builds are unsigned.
