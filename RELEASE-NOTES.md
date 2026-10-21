# uLEAPP 0.3.1 — Community Preview

Bug fixes across macOS, Windows and Linux:

- Keeps the Windows interface responsive during large downloads and reduces excessive progress updates.
- Stop now cancels active downloads and release checks on Windows and Linux. Stalled downloads time out.
- Improves Mac responsiveness by caching app icons and batching progress logs. Installed-app discovery can now be stopped.
- Includes Launch controls for installed apps on all three platforms.

Download the matching platform package and extract the complete folder. Windows
packages include the .NET runtime. The macOS package supports Apple silicon and
Intel and needs macOS 13+ and Homebrew. Linux needs Python 3.10+ and Tk; GLEAPP is
currently x64-only and requires glibc 2.39+. AppImages require FUSE support.
The full preview bundle includes all platform packages and source.
SHA256SUMS-0.3.1.txt verifies the release downloads.

An official installer or Homebrew installation already running finishes at a safe
boundary when Stop is requested. Windows builds are unsigned; the Mac app is ad
hoc signed and is not notarized. Linux/WSL real-app graphical launches remain
manual validation. Managed LEAPP apps and publisher icons retain their own terms;
LAVA is separately licensed freeware. No publisher endorsement is implied.
