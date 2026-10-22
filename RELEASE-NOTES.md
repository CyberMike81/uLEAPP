# uLEAPP 0.3.3 — Community Preview

- Linux launch failures now show the actual captured error and exit code in a scrollable dialog with **Copy error**.
- Each launch has a separate private log, preventing older errors from being shown for a new attempt.
- Removes the generic FUSE/glibc warning. Failures after the original startup check are also detected.

This improves diagnosis; it does not claim to fix the underlying GLEAPP failure
on openSUSE. The captured log is still needed to identify that cause.
Includes automatic uLEAPP update checks and all earlier fixes.

Download and extract the complete platform package. Windows includes .NET;
macOS requires macOS 13+ and Homebrew and supports Apple silicon/Intel. Windows
builds are unsigned and the Mac build is ad hoc signed without notarization.
Linux requires Python 3.10+ and Tk. AppImages may require FUSE; GLEAPP's tar.gz
package does not. GLEAPP requires glibc 2.39+ and currently publishes Linux x64
only. Real WSL compatibility remains unverified.
SHA256SUMS-0.3.3.txt covers all downloads.
