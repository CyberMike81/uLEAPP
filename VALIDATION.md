# uLEAPP 0.2.2 review status

Prepared 2026-10-14. Community preview 0.2.2. The user authorized public GitHub
publication and an email to Alexis for testing and feedback; no upstream PR is planned.
The independent re-audit confirmed all five fixes and found no new confirmed defects.

## Included builds

| Platform | App in platform root | Completed checks | Remaining manual coverage |
| --- | --- | --- | --- |
| macOS 13+ | `macOS/uLEAPP.app` | Universal Apple silicon/Intel binary; packaged CLI/resources/signature; 79 offline worker checks; real Homebrew integration with seven installed tools | Physical Intel Mac on macOS 13; clean Mac installation; real sudo prompt and cancellation |
| Windows ARM64 | `Windows-ARM64/uLEAPP.exe` | 115 packaged checks on Windows 11 ARM; user reported real installs and GUI use; actual publisher icons observed | Full final 0.2.2 click-through on a clean account, including folder choice and Stop |
| Windows x64 | `Windows-x64/uLEAPP.exe` | 115 packaged checks under Windows 11 ARM's x64 emulation; PE machine verified as x64 | Final uLEAPP build on a physical Intel/AMD Windows PC |

The Mac Intel CLI also passes under Rosetta. Emulation does not establish
compatibility on physical Intel hardware or older macOS runtimes. The current
Mac interface was inspected with all seven installed versions and publisher
icons. About credits **Idea by @CyberMike81**, with a GitHub link and no named
copyright ownership statement. The Desktop shortcut targets the app in `macOS/`.

The five confirmed defects from the independent 0.2.0 audit were fixed.
`AUDIT-RESPONSE.md` maps changes, evidence and open concerns.

## Behavior covered

- Only LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP, DLEAPP and GLEAPP are supported.
- Individual and bulk missing-app installation; installed-app updates; no
  forced replacement when adopting a matching manually installed Mac app.
- Homebrew's named-outdated exit code, bare cask version queries, exact token
  matching, genuine failures, preview mode and stopping between operations.
- Official Windows package selection, ambiguous-asset refusal, download
  size/SHA-256 checks, approved HTTPS redirects and unsafe-archive refusal.
- Portable updates preserve prior versions and files; failed replacements keep
  the working installation and recorded state.
- Invalid Windows settings recover with a visible notice and unique backup.
  If backup is blocked, originals remain unchanged and writes/installations
  are blocked. Self-checks use the regular user's temporary folder.
- All seven actual tool icons are bundled and decode before tool installation.
  Update controls disappear when installed tools are confirmed current.

The real Homebrew integration used a read-only adapter that skipped trust, tap
and refresh. A controlled `--minimum-version` query exercised Homebrew's actual
named-outdated exit 1 without changing an installed app. This establishes real
command semantics, not discovery of an actual newer published release. See
`macOS/tests/LIVE-HOMEBREW-CHECK.txt`.

## LAVA 0.15.0 on Windows ARM

The official native ARM setup left registration, support files and shortcuts,
but no `LAVA.exe` or main DLLs in the test VM. uLEAPP correctly refused to count
the shortcut alone as an installed app. Read-only security checks found no
matching LAVA Defender detections or blocking events in the logs checked;
security settings were not changed.

The official x64 setup, verified against its published SHA-256 and size, installed
the main executable and DLLs. The running executable was confirmed as x64
(`0x8664`) with window title **LAVA 0.15.0** on Windows 11 ARM. Its registered
`DisplayVersion` is `0.15.0`. The user subsequently confirmed uLEAPP detects it.
The user also reported successful LAVA installation on a separate x86/Intel PC;
that report is not a test of the final x64 uLEAPP build.

uLEAPP 0.2.2 selects the official x64 setup on ARM only for LAVA 0.15.0, retains
checksum validation and interactive setup, and prefers native ARM for later
releases. Selection has regression coverage. The comparative installation was
performed directly with the official setup; repeating that installation through
the final uLEAPP GUI remains a manual check. Evidence points to the native
ARM package, but is not a publisher-confirmed diagnosis of its internal cause.

## Evidence and limits

Each Windows platform includes `SELF-CHECK.txt`, `BUILD-INFO.json`, matching
runtime notices and artwork notices. SDK 10.0.402 and runtime packs 10.0.13 were
used. Tests contain synthetic temporary files and public release metadata; the
review package excludes forensic inputs, credentials and private user logs.

Built-artifact checks follow the applicable approach in the published
[iLEAPP](https://github.com/abrignoni/iLEAPP/blob/master/.github/workflows/test_builds.yml)
and [RLEAPP](https://github.com/abrignoni/RLEAPP/blob/main/.github/workflows/test_builds.yml)
workflows. uLEAPP changes no forensic parsers; parser regression suites and
maintainer acceptance are separate from updater validation.

The archive includes full source, all three root apps, `SHA256SUMS.txt` and
`REVIEW-MANIFEST.json`. Packaging verifies versions, architectures, exact Mac
icon resources, notices and self-check records, then repeats verification after
ZIP extraction, including the Intel Mac CLI under Rosetta. Checksums establish
file integrity, not publisher signing or remaining manual coverage.

## Licensing and release status

Original uLEAPP code and original artwork use the supplied MIT license; the idea
credit is not a code ownership claim. Required third-party notices remain intact.
The audit's optional licensor/holder question remains for review; no named
ownership statement was added against the user's instruction.

Six parser-app icons retain their upstream MIT notices. LAVA and its artwork
are separately licensed; its identifying icon is included by the maintainer
for publisher review. No standalone artwork permission grant is claimed. See `THIRD-PARTY-NOTICES.md` and
`assets/tool-icons/` for provenance and terms. No LEAPP executables or installers
are bundled. Apple/Windows platform tools, Parallels and Codex are vendor tools
or services, not redistributed open-source dependencies.

The Mac signature is local ad hoc, with no Developer ID notarization. Windows
builds are unsigned. This preview is offered for feedback; the remaining manual coverage is listed above.
