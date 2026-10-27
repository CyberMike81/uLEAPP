# uLEAPP 0.3.14 validation

Prepared October 27, 2026. This release changes Windows portable install locations
and recovery; Mac and Linux changes are version metadata only. Earlier independent
audits do not cover this new installation path.

Windows builds use .NET SDK 10.0.403 and runtime packs 10.0.14 with matching
licenses and notices. Windows native x64 and ARM64 builds run 211 packaged self-checks, including real
WPF properties, isolated Start menu shell links, installation integration and
legacy cleanup. New location checks cover explicit first-install folder choice,
exact executable-path preservation across updates, original rollback folders,
case-file preservation, installer-to-portable migration, checksum and selection-
write failures, rejecting occupied/shared folders, cancellation, interrupted swaps,
completed publication before selection recording, unreadable recovery records,
and retaining recovery journals until selection is successfully persisted.

Staging is beside the selected app on the same volume. The original tree is copied
with unknown files intact; content hashes detect changes during preparation. Linked
paths and shared/system root folders are refused. After verification, a journal is
flushed before swapping directories. Selection-save failure rolls the swap back;
startup recovery restores a missing original folder or records a fully published
replacement. No fallback AppData installation occurs. Original rollback folders
are kept for manual review and are excluded from legacy automatic cleanup.

Program Files subfolders are valid targets but remain subject to Windows access
checks. Denied access explains that the user should reopen uLEAPP as administrator
or fix permissions. This feature does not introduce an elevated background helper.
Publisher setup installers still control their own installation flow. Existing
Windows uninstall records are preserved and may continue showing the old version
after a portable transition; uLEAPP tracks the selected version independently.

Native Windows build evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40599230996
Linux x64/ARM64 test and package evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40598726358

Mac verification includes a universal build, native and Rosetta self-checks, strict
signature and resource/version smoke checks. Linux runs 36 core tests and native
CI desktop/extracted-package smoke checks. All public package digests, executable
versions and architectures are verified before publication.

Remaining manual coverage: real Windows folder-picker and UAC/permission flows,
Start menu search/click-through, locked files and unusual NTFS ACLs, large folders
and disk exhaustion, real publisher upgrades in Program Files, registry uninstall
behavior after a portable transition, and full GUI/installer behavior on hardware.
Intel Mac/macOS 13, actual App Management denial, Linux publisher GUI/WSL and Batch
under Windows ARM emulation remain hardware gaps. Existing Batch artwork permission
is unresolved. Mac builds are ad hoc signed, Windows builds unsigned.
