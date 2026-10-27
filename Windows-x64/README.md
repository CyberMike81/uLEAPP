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

Windows updates now keep the selected app's existing folder and executable path.
Portable downloads are checksum-verified and prepared in a staging folder beside
the app, with its original folder retained as a `.uleapp-previous-...` rollback
copy. Unknown files and reports are copied into the replacement; rollback copies
are kept for manual review because they can contain case data. Extra disk space
is needed to stage the complete folder. Existing case files should be stored
outside app folders where possible. Do not edit the app folder during an update.

For a first portable installation, uLEAPP asks you to choose an empty, dedicated
app folder. Cancelling skips that app. Settings → Choose folder only changes the
suggested location, not existing apps. The default suggestion is a LEAPPs folder
under your user profile. uLEAPP keeps its settings and logs in AppData.

Existing Windows installer records and saved selections are detected. The row's
⋯ menu → **Use existing installation…** lets you select an app elsewhere, including
an original copy if an earlier uLEAPP version selected a separate portable copy.
Selection does not move, remove or update either copy. A portable update to a
previous installer location is tracked by uLEAPP; the old Windows uninstall record
is left unchanged. Full publisher installers still control their own setup.

Program Files updates require Windows permission: if access is denied, reopen
uLEAPP as administrator and retry. No fallback copy is installed in AppData.
Linked or shared app folders are refused. Failed checksums, cancellation or saving
selection leave the working installation in place; an interrupted folder swap is
recovered on the next start. Start menu shortcuts refresh after success.

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

When a publisher stops offering setup installers, its official portable ZIP can
update the selected copy in the same app folder. The original folder is retained
as a rollback copy; no separate portable-app location is selected automatically.
Setup remains preferred when published; LAVA requires its official installer.

## Remove old installs

This action covers the older version-folder layout. The same-location update's
`.uleapp-previous-...` rollback folders are retained for manual review and are not
automatically removed, because they can include files from the original install.

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

## Companion tools (0.3.14)

GLEAPP Map Downloader can be checked, installed, updated and launched on Mac,
Windows and Linux, with native x64 and ARM64 packages where published. It downloads
map data when you use it; GLEAPP itself remains offline.

Batch LEAPP is supported on Windows x64 (including Windows ARM through x64
emulation). Its current Mac GUI is Apple silicon only and requires manual download
and installation: the publisher's v1.2.0 app is ad hoc signed, not notarized, and
reports bundle version 0.0.0. uLEAPP offers the exact official Mac download and
can launch an existing Applications copy; it does not disable Gatekeeper or claim
that copy is up to date. No Linux or Intel Mac Batch package is currently published,
so those platforms do not offer it. All tools use their publishers’ official release downloads.

Companion updates use the same location and rollback-copy rules as other Windows
tools. Cleanup of older version-folder installs remains available. Manually selected
external app folders and the new rollback copies are outside automatic cleanup.

0.3.14 groups preferences under Settings and logs under Details. Tool status
pills include versions; hover for check evidence. Row menus reveal installed
copies and open release notes. All platforms use official publisher releases;
there is no update-method choice.

## Start menu shortcuts (0.3.14)

“Create Start menu shortcuts” in Settings is enabled by default. After a successful
install or update, uLEAPP creates or refreshes a shortcut under your own Start menu
in the uLEAPP folder. This also works when Update apps finds an installed tool is
already current. Apps stay in their existing install locations; no administrator
permission is needed for shortcuts. Only shortcuts marked as created by uLEAPP
are replaced. Custom and publisher shortcuts are left alone.

Failed installations leave working shortcuts intact. A shortcut failure does not
undo an app update: Details explains the problem and you can still use Launch.
Turning the setting off stops future shortcut changes and keeps existing entries.
