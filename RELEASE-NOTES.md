# uLEAPP 0.3.7 — Community Preview

- Mac direct installs now require the LEAPP publisher’s Developer ID team and a successful Gatekeeper assessment. Quarantine is applied before selecting the app; older direct copies are checked and quarantined when launched through uLEAPP.
- Mac rows show both Homebrew and direct versions and explain the selected Launch copy. **Return to Homebrew** switches only after the cask and app in Applications have caught up and verification succeeds. Direct app folders are preserved.
- Windows cleanup now requires the shell’s Recycle Bin destination confirmation, refuses non-fixed drives, and checks known disabled-recycling settings.
- All platforms offer a saved **Check for uLEAPP updates automatically** setting and a `--no-update-check` option. Release checks reuse ETags; rate-limit failures show remaining quota and reset details in Details. Unauthenticated checks still share GitHub’s hourly IP limit.
- The live Homebrew integration test now picks a Homebrew-managed cask dynamically instead of assuming iLEAPP is still Homebrew-managed.

Includes all earlier fixes, portable Windows updates, direct Mac updates and manual old-install cleanup on all three platforms. Mac requires macOS 13+ and Homebrew; Windows packages include .NET; Linux requires Python 3.10+ and Tk. uLEAPP’s Mac build is ad hoc signed without notarization and Windows builds are unsigned.

SHA256SUMS-0.3.7.txt covers all downloads.
