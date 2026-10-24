# uLEAPP for Windows

Native Windows installer/updater for LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP,
DLEAPP and GLEAPP. Idea by [@CyberMike81](https://github.com/CyberMike81).
uLEAPP's original code and artwork are MIT licensed, with no named ownership
claim. Managed apps retain their own licenses. LAVA is separate freeware.

## Run

Open `uLEAPP.exe` from the platform folder:

- `../Windows-ARM64/` for Windows 11 on ARM, including the Parallels VM.
- `../Windows-x64/` for Intel/AMD Windows PCs.

Keep the complete folder together, including `LICENSE`, `licenses/` and
`runtime-notices/`. The .NET runtime is included; no separate runtime install
is needed. On launch, only uLEAPP release metadata is checked; no app packages are downloaded or installed.
The LEAPP and companion icons are embedded, so they appear before the apps are
installed. Publisher artwork keeps its own terms; see `artwork-notices/`.

Choose **Check for updates**, **Update apps**, **Install** beside a missing
app, or **Install missing apps**. Close your LEAPP apps before updating.
The official LAVA setup remains interactive and has its own license terms.
Once a tool is confirmed up to date, its Update button disappears and Launch
remains available. The bulk Update button disappears when all installed tools
are confirmed current. Check for updates and missing-app installation remain.
GLEAPP currently supplies x64 packages; Windows 11 ARM uses Windows' x64
emulation for that tool. uLEAPP itself has a native ARM64 build.
LAVA 0.15.0 also uses the official x64 setup on Windows ARM because its native
ARM setup left the main executable and DLLs missing in the test VM. This exception
applies only to 0.15.0; later releases prefer a native ARM package. Downloads keep
the publisher's checksum verification and normal interactive setup.

Portable apps default to `%LOCALAPPDATA%\LEAPPs`. **Choose folder** can change
the location on a Windows drive. Existing setup-installed apps are found
through their Windows installation records; portable apps in the selected
folder are also detected. Apps elsewhere can be placed under the selected
folder. uLEAPP does not search case/evidence drives or modify forensic data.

Portable updates use a new version folder and keep older versions and files.
Use **Launch** beside an app to open the selected version. Setup-installed
copies update through the publisher's interactive setup. A failed download
or checksum blocks installation; other requested apps can still finish.
**Stop** cancels checks and active downloads. An official installer already running finishes safely.

Logs are under `%LOCALAPPDATA%\uLEAPP\Logs`; state is in that app's
`settings.json`. No account credentials or telemetry SDK are used by uLEAPP.
Unreadable settings recover to defaults with a visible explanation. The original
file is preserved as a uniquely named `.bak` file. If it cannot be backed up,
the original stays untouched and installations/settings changes wait until access
is restored. Choose folder to reconnect a previous custom portable-app location.

## Build and test

Requires a Windows .NET 10 SDK. There are no third-party application package
references. The SDK supplies/restores Microsoft's runtime and build packs
from the official NuGet source. `tools/InstallWindowsSdk.ps1` documents a
task-local SDK download with Microsoft's SHA-512 verification; it changes
no PATH or script execution policy.

From an approved PowerShell development environment:

```powershell
./tools/Build.ps1 -DotnetPath 'C:\path\to\dotnet.exe'
```

The build publishes both architectures, copies the exact runtime licenses,
adds WPF's matching third-party notices, and runs `--selfcheck` against the
packaged executable. Test fixtures contain public upstream release metadata,
not LEAPP application code or binaries. `--demo` previews a clean install;
`--demo-installed` previews installed apps without downloads or app changes.
Run self-checks from a regular Windows user account: they use that account's
temporary folder, not Public Documents. The installer deliberately rejects
Windows system folders, including the default temporary folder of SYSTEM.
The single-file .NET app extracts native runtime files under `%TEMP%\.net\uLEAPP`
when needed; this requires a usable Windows temporary folder.
`--diagnose-app lava` reports whether LAVA's registered executable actually exists,
plus its version and path. Other supported lowercase tool IDs can also be used.
This diagnostic reads registration only and makes no settings or app changes.

Both Windows preview builds are unsigned. Maintainer testing and feedback are welcome.
The LAVA identifying icon retains its separate EULA and provenance; no standalone
artwork permission grant is asserted.

Stop cancels release checks and active downloads. Downloads fail after 60 seconds
without data. An official setup already running finishes safely; the next app
will not start. Download progress is throttled to keep the interface responsive.

## uLEAPP update notifications

uLEAPP checks its own official GitHub releases at startup and once every 24 hours
while open. A newer published release shows **Download update** for your platform
and a **Release notes** link. Downloads open in your browser only when clicked;
no automatic installation or replacement occurs. This is separate from LEAPP
tool checks. Offline/rate-limit failures stay quiet and do not block normal use.
Demo and automated smoke-test modes do not contact GitHub.

When a publisher stops offering setup installers, an installer-managed copy can
be updated using its official portable ZIP for the same architecture. The new
copy is installed in the selected portable-app folder and becomes uLEAPP’s
launch target. The older registered copy is preserved. Setup remains preferred
when published; LAVA continues to require its official installer.

## Remove old installs

**Remove old installs** reviews eligible older uLEAPP-managed app folders before
moving them to Recycle Bin/Trash. It keeps the current version and one previous
version per tool. Cleanup is manual; checking or installing never removes old
versions automatically. A file inventory saved by new installs protects added
case/report files, changed app files and links. Older folders without this
inventory are preserved. Eligibility is checked again after review.

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

## Companion tools (0.3.12)

GLEAPP Map Downloader can be checked, installed, updated and launched on Mac,
Windows and Linux, with native x64 and ARM64 packages where published. It downloads
map data when you use it; GLEAPP itself remains offline.

Batch LEAPP is supported on Windows x64 (including Windows ARM through x64
emulation). Its current Mac GUI is Apple silicon only and requires manual download
and installation: the publisher's v1.2.0 app is ad hoc signed, not notarized, and
reports bundle version 0.0.0. uLEAPP offers the exact official Mac download and
can launch an existing Applications copy; it does not disable Gatekeeper or claim
that copy is up to date. No Linux or Intel Mac Batch package is currently published,
so those platforms do not offer it. Companions use direct downloads, not Homebrew.

Managed companion installs retain the current and previous versions and participate
in **Remove old installs**. Manually installed Batch copies are outside that cleanup.

0.3.12 groups preferences under Settings and logs under Details. Tool status
pills include versions; hover for check evidence. Row menus reveal installed
copies and open release notes. Mac Homebrew switching stays disabled until
both the installed Homebrew version and its Applications copy have caught up.
