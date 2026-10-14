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
is needed. The app makes no downloads or application changes on launch.
The actual seven LEAPP icons are embedded, so they appear before the apps are
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
**Stop after this app** waits for the current operation to finish.

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
