# uLEAPP for Mac

Idea by [@CyberMike81](https://github.com/CyberMike81).

A local desktop updater for the seven LEAPP apps distributed by the official `leapps-org/leapps` Homebrew tap: LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP, DLEAPP and GLEAPP.

The app shows installed versions, checks for updates, updates installed tools, and offers **Install** beside a missing app plus **Install missing apps** for the group. **Launch** opens an existing app from `/Applications` or your personal `~/Applications` folder, including manually installed apps. Launch is unavailable while an update or installation is running. Details and logs are available when an operation needs attention. Batch LEAPP and GLEAPP Map Downloader are outside this version's scope.

## Build and run

Requires macOS 13 or newer and Apple's Command Line Tools. No downloaded libraries are needed. The build contains Apple silicon and Intel binaries.

```sh
bash tools/build.sh
open uLEAPP.app
```

Homebrew must be installed to use the updater. Close your LEAPP apps before choosing **Update apps**. Checking refreshes Homebrew's package metadata; updating changes only the named installed LEAPP casks and their required dependencies. Missing apps are installed only when you choose an installation action. Installation actions leave already-managed apps alone.

The standalone updater is in `scripts/LEAPP Updater.command`; it can also be double-clicked from Finder. `--dry-run` previews without changing Homebrew or apps. `--check` refreshes Homebrew and checks without upgrading. `--install lava` installs one supported cask; `--install-missing` installs the missing supported tools.

## Authorization

When Homebrew needs administrator access, its standard `SUDO_ASKPASS` mechanism opens a local secure password field. That helper passes the password directly to `sudo`; the updater does not receive it through its output stream, save it, or put it in logs. Cancelling authorization makes that operation fail and the updater continues with the other apps. The **Stop after this operation** control waits for the current Homebrew command to finish.

For a manually installed app, the **Add** action asks Homebrew to adopt a matching copy. It uses `--adopt` and never forces replacement; a different existing copy is left intact and reported in Details. LAVA is freeware under a separate EULA; first-time GUI installation offers its license before proceeding.

## Test

```sh
bash tests/test_updater.sh
uLEAPP.app/Contents/MacOS/uLEAPP --selfcheck
open uLEAPP.app --args --demo
open uLEAPP.app --args --demo-missing
```

The shell tests use a fake Homebrew and change no installed apps. Demo mode simulates status changes without running Homebrew. The normal app reads your actual installed casks and checks uLEAPP release metadata on launch; no app packages are downloaded.

## Icon and distribution

`tools/MakeIcon.swift` contains original vector artwork, including hand-drawn arrows and lettering. Its lime green, pink, orange and black palette follows the existing LEAPP family. No SF Symbols or font outlines are used in the icon. Installed app icons are read from local Applications folders at runtime and are not redistributed.

uLEAPP source and artwork are MIT licensed. See the repository's `LICENSE`, `THIRD-PARTY-NOTICES.md` and `licenses/`. The Mac package includes these notices; About links to them. Apple system frameworks and tools remain under Apple's platform terms.

The local build uses an ad hoc signature. Public distribution still needs a release process, including Developer ID signing and notarization. Community Preview downloads are published on GitHub.

## Windows

This build is for macOS. The separate Windows source is in `../Windows/`, with outputs in `../Windows-x64/` and `../Windows-ARM64/`. Windows uses verified official release downloads and preserves previous portable versions. Windows x64 and ARM64 package checks run on native GitHub runners; manual installation/UI coverage remains in VALIDATION.md.

Homebrew remains the first installation source. Before reporting an app as current,
uLEAPP also checks the publisher’s latest stable GitHub release. If GitHub is newer,
**Homebrew update pending** offers **Update** to download, verify and install the
correct Apple silicon/Intel app directly. **Update apps** uses the same fallback
for pending releases after Homebrew finishes. Checks alone never download apps.

Direct copies live in versioned folders under `~/Applications/uLEAPP`, with selected
version records in `~/Library/Application Support/uLEAPP/direct-installs`. Launch
uses the selected direct copy; old copies and Homebrew’s bundles/receipts remain
intact. Future checks use the direct version and do not downgrade it through
Homebrew. Direct download cancellation and errors are shown in Details.
The downloaded image’s SHA-256, app version, processor support and signature are
verified before the selected-install record changes. The GUI casks remain the
supported Homebrew targets; the deprecated separate CLI formulae are not used.

Installed-app discovery can be stopped and has a 60-second deadline. Homebrew
installation Stop still waits for the current operation to finish safely. Icons
and app paths are cached between refreshes; progress logs are coalesced.

## uLEAPP update notifications

uLEAPP checks its own official GitHub releases at startup and once every 24 hours
while open. A newer published release shows **Download update** for your platform
and a **Release notes** link. Downloads open in your browser only when clicked;
no automatic installation or replacement occurs. This is separate from LEAPP
tool checks. Offline/rate-limit failures stay quiet and do not block normal use.
Demo and automated smoke-test modes do not contact GitHub.

Optional real-package integration check (downloads official ALEAPP and installs
only in an automatically removed temporary home):

```sh
python3 tests/live_direct_install.py
```

## Remove old installs

**Remove old installs** scans only uLEAPP-marked direct installation folders,
keeps the selected version and one previous version per app, and shows a list
before moving eligible older copies to Trash. The scan rechecks the records and
app signatures after confirmation. Homebrew copies, unmarked folders, folders
with extra files and changed apps are left alone. Cleanup never runs automatically.

## Automatic checks and network use

The saved **Check for uLEAPP updates automatically** setting controls the startup
and daily uLEAPP metadata request. Uncheck it to stop those requests, or launch
with `--no-update-check` to disable them for that run. Explicit tool checks and
installation requests still contact the publishers when requested. No case data
is included in these requests; the User-Agent identifies the uLEAPP version.

Metadata requests send cached ETags and use cached content only when GitHub
confirms it with HTTP 304. Network failures never become a cached “up to date”
result. GitHub’s unauthenticated limit is shared by source IP (typically 60/hour);
conditional requests are not exempt without authentication. Details show the
remaining quota and reset timestamp on HTTP 403/429. No GitHub token is stored.

## Direct copies and returning to Homebrew

Rows show the recorded Homebrew and direct versions. uLEAPP’s Launch uses the
selected direct bundle under `~/Applications/uLEAPP`; Finder, Spotlight and Dock
items pointing into `/Applications` can still open the older Homebrew bundle.
**Return to Homebrew** refreshes the cask and checks that its published version
and actual app in Applications are at least as new as the selected direct copy.
Only after publisher/Gatekeeper verification succeeds is the direct selection
record removed. Direct folders remain available for manual rollback; Homebrew
resumes managing subsequent checks. A failed/too-old return keeps direct selected.

Direct installs and Launch of older direct copies enforce LEAPP team `N2G83326TZ`,
Gatekeeper assessment and quarantine. Other teams and ad hoc publisher apps are
refused; this is separate from uLEAPP’s own ad hoc-signed preview build.
