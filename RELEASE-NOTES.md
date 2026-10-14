# uLEAPP 0.2.2 community preview

Desktop installer/updater for LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP, DLEAPP and
GLEAPP, with Mac, Windows ARM64 and Windows x64 builds. It began as a Homebrew
script and now provides a native GUI for checking versions, installing missing
apps and updating installed tools with visible status and logs.

The 0.2.0 audit's five confirmed defects are fixed. The independent 0.2.2
re-audit confirmed those fixes and found no new confirmed defects. The updater
source is unchanged from the audited 0.2.2 review archive; this publication adds
screenshots and refreshes release documentation/notices. Mac package resources
were re-signed locally after the notice refresh.

Validation: 79 Mac worker checks; 115 packaged checks for each Windows build on
Windows 11 ARM (x64 uses emulation); Mac native/Rosetta package checks and real
Homebrew command-semantics checks. See VALIDATION.md for manual coverage and
optional improvements still pending. Windows builds are unsigned; Mac uses an
ad hoc signature, without notarization.

The LAVA 0.15.0 x64-on-ARM selection is version-specific and does not prevent
new releases from being discovered automatically. Publisher icons retain their
separate terms; full notices and provenance are included.

Please try the matching ZIP and share bugs, usability suggestions or packaging
feedback. This preview is offered for Alexis and the community to evaluate;
LEAPP collection/website inclusion and endorsement remain the maintainers' decision.
