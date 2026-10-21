# uLEAPP 0.3.2 — Community Preview

- Automatically checks for new uLEAPP releases at startup and once every 24 hours while open.
- Shows **Download update** for your platform and a **Release notes** link when a newer version is available.
- Checks run separately from LEAPP tool updates. Offline and rate-limit errors stay quiet; no automatic installation occurs.
- Includes the download responsiveness, Stop, timeout and Mac performance fixes from 0.3.1.

Download and extract the complete platform package. Windows includes the .NET
runtime. macOS supports Apple silicon and Intel, requires macOS 13+ and Homebrew,
and is ad hoc signed without notarization. Windows builds are unsigned. Linux
requires Python 3.10+ and Tk; AppImages require FUSE, and GLEAPP is currently x64-only
with glibc 2.39+. Real WSL compatibility remains unverified.

SHA256SUMS-0.3.2.txt covers all downloads. The full preview bundle contains all
platform builds and source. Existing 0.3.1 installations need this one manual
update to gain the new automatic check and Download update button.
