# uLEAPP for Linux · 0.3.8 preview

Install, update and launch the seven LEAPP apps from their official GitHub releases.
This Linux preview uses Python 3.10+ and Tk; no Python packages from pip are needed.
It installs apps for your user without sudo. It does not adopt existing installations.

On Ubuntu/Debian, install the interface dependencies:

```sh
sudo apt install python3 python3-tk
./uleapp
```

Extract the complete Linux archive before running `uleapp`. For a source checkout,
run `./Linux/uleapp` from the repository root. Use `--demo` to preview without changes.

Choose **Check for updates**, then **Install** or **Update** beside a tool. **Launch**
opens an installed tool. **Update installed apps** updates the managed group.
Startup checks only uLEAPP release metadata on GitHub; no app packages are downloaded. **Stop** cancels checks, downloads and preparation; completed installations are kept. LAVA asks you to review and accept its separate
license before installation. Other publishers' terms remain applicable; the
archive includes uLEAPP's license and third-party notices.

Apps live in `$XDG_DATA_HOME/uLEAPP/apps` (default `~/.local/share/uLEAPP/apps`).
Each release has its own folder; old releases and case files are preserved.
Launch logs are in the adjacent `logs` folder. Close LEAPP apps before updating.
Installations are selected only after their complete download, size and SHA-256
have been verified. A failed installation leaves the previous selection intact.

Linux x64 and ARM64 are supported; a tool is unavailable when its publisher has
no package for that architecture. GLEAPP currently publishes only x64 Linux,
requires glibc 2.39+ (Ubuntu 24.04+), and uses a tar archive. The other six tools use
AppImages. AppImages generally need FUSE installed by your distribution; uLEAPP
reports early launch failures and points to the app's log. No x64 emulation is
attempted on ARM64. GitHub rate limits and network errors appear in Details. Downloads abort after 60 seconds without data (socket errors may occur sooner).
The interface needs a Linux graphical desktop. The preview has automated tests;
real LEAPP launches on Linux hardware remain to be verified.

Run tests with `python3 -m unittest discover -s Linux/tests -v` from the repository
root. Build the distributable with `python3 Linux/package.py`; it is a portable
source archive, not a bundled Python executable. Python and Tk must be installed
on the destination computer. GitHub Actions runs core tests and a GUI smoke check
under a virtual Linux display, then saves the archive as a workflow artifact.

## uLEAPP update notifications

uLEAPP checks its own official GitHub releases at startup and once every 24 hours
while open. A newer published release shows **Download update** for your platform
and a **Release notes** link. Downloads open in your browser only when clicked;
no automatic installation or replacement occurs. This is separate from LEAPP
tool checks. Offline/rate-limit failures stay quiet and do not block normal use.
Demo and automated smoke-test modes do not contact GitHub.

Failed launches show their captured output and exit code in a scrollable dialog
with **Copy error**. Each launch gets a separate private log under `logs`, named
for the tool (for example `gleapp-....log`); the dialog shows the exact path.
Empty or unreadable logs are reported explicitly. The launcher does not infer
missing dependencies from an exit code. Earlier `gleapp.log` files are preserved.

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
