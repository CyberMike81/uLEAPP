# uLEAPP for Mac

Idea by [@CyberMike81](https://github.com/CyberMike81).

Install, update and launch the LEAPP tools using their official publisher releases.
Requires macOS 13+; the same uLEAPP app runs on Apple silicon and Intel Macs.
No package-manager setup is needed.

## Install and use

Download the Mac package from the [0.3.12 Community Preview](https://github.com/CyberMike81/uLEAPP/releases/tag/v0.3.12), extract it and copy uLEAPP.app into Applications.

**Check for updates** reads official release metadata. **Update apps** installs
newer compatible releases; **Install** adds a missing tool. Close LEAPP apps first.
**Launch** reads the current selected-install record again and opens the latest
successfully installed copy. Failed or cancelled updates retain the working selection.

Existing apps in `/Applications` and `~/Applications` are detected automatically.
uLEAPP installs official updates in `~/Applications/uLEAPP/<tool>/<version>/` and
keeps its selection in `~/Library/Application Support/uLEAPP/direct-installs/`.
Existing Applications copies and external installer records are left intact.

Each row has one status/version pill and a quiet source description. Hover for
GitHub check evidence. The **⋯** menu opens release notes or reveals the selected
copy. **Settings** contains automatic uLEAPP checks; **Details** contains logs.
The footer shows the last check time.

## Companion tools

Map Downloader supports both Mac architectures and uses the same verified install
flow. Batch LEAPP currently publishes an Apple silicon GUI ZIP only. **Get latest**
opens that exact official download for manual installation; **Launch** opens an
existing Applications copy. Its current build is not notarized and reports version
0.0.0. macOS may block first launch, and uLEAPP does not claim it is current or
bypass system security checks. Intel Macs do not show Batch.

## Verification and permissions

Before selecting an installed release, uLEAPP checks download size and SHA-256,
the app version and architecture, the Apple-anchored Developer ID publisher team
`N2G83326TZ`, and Gatekeeper assessment. The staged app receives quarantine.
Launch rechecks a uLEAPP-managed copy before opening it.

If macOS denies a required security attribute, the message offers **Open Settings**
and explains **Privacy & Security → App Management**. Grant permission yourself and
retry. Existing quarantine values are preserved on Launch.

**Remove old installs** reviews older marked version folders before moving them to
Trash. The current and previous selected versions, unknown folders, modified apps
and case data are kept. Manual Applications copies are outside this cleanup.

## Build and test

Requires Apple Command Line Tools; no downloaded build libraries are needed.

```sh
bash tools/build.sh
python3 tests/smoke.py
uLEAPP.app/Contents/MacOS/uLEAPP --selfcheck
arch -x86_64 uLEAPP.app/Contents/MacOS/uLEAPP --selfcheck
```

Optional native integrations install into temporary test homes:
`python3 tests/live_direct_install.py` and `python3 tests/live_companions.py`.
`--demo` and `--demo-missing` preview the interface without downloading or launching
tools. `--no-update-check` disables automatic uLEAPP requests for one run.

Automatic uLEAPP checks run at startup and daily while open; downloads start only
when chosen. Replacing uLEAPP itself remains manual. This Community Preview is ad
hoc signed and not notarized. See the root validation and license notices.
