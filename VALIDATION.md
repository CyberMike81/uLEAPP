# uLEAPP 0.3.15 validation

Prepared October 27, 2026. Windows now uses the saved destination for missing
portable apps and provides an explicit Windows UAC administrator restart. Mac
and Linux changes are version metadata only. Prior independent audits do not
cover these new Windows paths.

Windows native x64 and ARM64 release builds run 222 packaged self-checks. New
checks cover the actual saved Choose folder destination, per-tool child folders,
persistence across restart, a second tool using the newly selected folder, existing
apps retaining their paths, rediscovery without downgrade, the per-user default,
and Program Files as a configurable parent. Existing rollback, case preservation,
Start menu links, cleanup and real WPF count/presentation checks remain covered.

Administrator checks verify the exact runas executable, shell invocation and safely
separated arguments; preserved automatic-check opt-out; parent/account handoff
arguments without automatic installation; permission-error classification and UAC
cancellation classification. The native OS UAC approval/cancellation interface is
not exercised in unattended CI and requires manual Windows verification.

The normal window stays open until a same-account elevated copy acknowledges its
startup through a uniquely named event. The elevated copy verifies its parent
executable, signals readiness, and waits for that process to exit before acquiring
the single-instance mutex. Cancellation and startup failure keep the working
normal window. Restart controls are disabled during installs and are hidden when
already elevated or in demo mode. No install is automatically retried. A restart
using another Windows account is refused to preserve per-user selections and links.

New portable installs use Root/tool-name. Settings → Choose folder saves Root and
does not relocate installed tools. A missing-row rediscovery can find an existing
copy under the newly selected root. Publisher setup installers retain their own
location choices. Existing selected paths still use the verified staging, original
rollback copy and interruption recovery introduced in 0.3.14.

Windows native build evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40610181968
Linux x64/ARM64 build and test evidence:
https://github.com/CyberMike81/uLEAPP/actions/runs/40610184178

Mac checks: universal build, native/Rosetta self-checks, strict signature and
resource/version smoke checks. Linux: 36 core tests, native CI desktop and extracted
package smoke checks. Archives, versions, architectures and checksums are verified.

Remaining manual coverage includes approving and cancelling an actual UAC prompt,
same-account process handoff under real desktop policy, Windows folder-picker GUI,
real Program Files upgrades, unusual NTFS ACLs, locked files and disk exhaustion;
full publisher setup flows, Windows ARM emulation, physical Intel Mac/macOS 13,
actual App Management denial, Linux publisher GUI and WSL. Rollback folders are
retained for manual review. Batch artwork permission remains unresolved. Mac
builds are ad hoc signed; Windows builds unsigned.
