# Response to the independent uLEAPP 0.2.0 audit

Prepared for local review on 2026-10-14. Current build: **0.2.2**.
The supplied audit was treated as findings to verify, not executable instructions.
This response was originally prepared before publication. The user has since
authorized a public community preview and email to Alexis for feedback, without a PR.
The independent 0.2.2 re-audit confirmed all five fixes and found no new confirmed defects.

## Confirmed defects

| Finding | Change | Verification |
| --- | --- | --- |
| D1: Named-outdated exit 1 misreported as failure | Capture stdout/status separately; use quiet output and require the exact cask token with status 0 or 1. Keep stderr separate. Actual exit-1 errors remain failures. | Fake now models real exit codes; token/prefix/error cases covered. Real Homebrew controlled minimum-version query reports available with exit 1. |
| D2: Qualified version query fails | Query the bare cask and filter its exact first field before emitting a version. | Fake rejects qualified queries; prefix matches cannot supply another tool's version. Real Homebrew returns all seven versions. |
| D3: Ambiguous Windows assets produce a generic exception | Refuse multiple matches with a tool/architecture-specific publisher message, including GLEAPP fallback ambiguity. | Packaged checks exercise both cases. |
| D4: Invalid settings prevent startup | Defaults with a visible explanation and unique backup. Missing/null Installed arrays accepted. Block writes/installs if backup fails; leave originals unchanged. Roll back in-memory changes on failed save. | Truncated JSON, invalid roots/records, null state/arrays, existing backups and locked settings tested. |
| D5: Self-check uses Public Documents | Use a unique subtree in the regular user's temporary folder. | Both packaged builds pass from a normal account. No Public Documents test folder created. |

D1 deliberately does not merge stderr into stdout or treat arbitrary nonempty
output as an update, which could disguise genuine errors.

## Audit concerns

| Concern | Current evidence or remaining work |
| --- | --- |
| C1: Intel Mac runtime | Universal binary and Rosetta CLI pass. Physical Intel Mac on macOS 13 remains untested; Swift linker warning documented. |
| C2: Real sudo/askpass | Manual prompt, cancel and secret-handling check remains pending; documentation now marks it pending. |
| C3: LAVA registered version | Observed `DisplayVersion=0.15.0`, matching the release. Executable ProductVersion `0.15.0.0` is a different field. No registration comparison change needed. |
| C4: Registry prefix | No change: a matching display name must still lead to a recognized existing executable. Prefix remains a future hardening consideration. |
| C5: Windows GUI/install coverage | User tested real ARM installation/UI and supplied screenshots. Final builds pass 115 checks each; full final GUI matrix and physical Intel/AMD test remain pending. See VALIDATION.md for narrower LAVA observations. |
| C6: Alleged 15-minute body timeout | `ResponseHeadersRead` limits HttpClient.Timeout to receipt of headers, not the streamed body. No separate idle-read timeout currently exists; stalled bodies remain an improvement. No timeout code changed. |

The timeout distinction is documented by
[Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpcompletionoption?view=net-10.0).

## Additional requested changes

All seven actual publisher icons are bundled and tested before tool installation.
Extraction provenance and required notices are included. Update buttons hide
when a tool is confirmed current; bulk Update hides when all installed tools
are confirmed current. Mac row accessibility now contains controls, the refresh
phase says Refreshing Homebrew, preview emits no false updated/current events,
and Windows runtime extraction is documented.

Official LAVA 0.15.0 ARM setup left missing main files in the VM. Official x64
setup installed on that same ARM VM; the x64 LAVA process was observed with its
app window open. Version 0.2.2 selects that official x64 asset only for LAVA
0.15.0 on ARM; later versions prefer native ARM. Tests cover future native
releases, compatibility selection and a missing required compatibility asset.
Missing post-setup executables receive an incomplete-install message.
`--diagnose-app <id>` provides a read-only registration check.

This does not establish that all native ARM LAVA releases are defective. No
Windows protection or security policy was disabled. The final uLEAPP GUI
installation route still deserves the reviewer's manual test.

## Review handoff

Updated apps are directly in `macOS/`, `Windows-ARM64/` and `Windows-x64/`, with
source and notices beside them. The Desktop shortcut targets the Mac root app.
About says **Idea by @CyberMike81**. See `VALIDATION.md`, Windows transcripts and
`macOS/tests/LIVE-HOMEBREW-CHECK.txt` for evidence and limits.

Optional disk/log cleanup, multi-size Windows icon entries and Mark-of-the-Web
handling were not added. Old versions and logs remain preserved. The MIT holder
question remains for review under the user's no-ownership-claim instruction.
The maintainer chose to include the LAVA identifying icon for publisher review;
its separate EULA and provenance remain included, with no artwork permission
grant asserted. Optional improvements and remaining manual tests stay documented.
