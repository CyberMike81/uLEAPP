# uLEAPP 0.3.12 validation

Prepared October 24, 2026. Current workflow: official publisher releases on every
platform. Earlier package-manager validation is historical only and is preserved
in docs/VALIDATION-through-0.3.11.md and macOS/legacy/.

| Platform | Completed checks | Remaining manual coverage |
| --- | --- | --- |
| Mac 13+ | Universal arm64/x86_64 build; native and Rosetta self-checks; strict ad hoc signature and resources; all official-release selectors; per-user selected records and cleanup; no retired worker/password helpers in the app | Physical Intel Mac on macOS 13; clean-machine install and App Management grant flow |
| Windows x64 | Native packaged build and 187 self-checks, including actual WPF count properties and status/version presentation | Full manual GUI/installer flow on user hardware |
| Windows ARM64 | Native packaged build and 187 self-checks; native or explicit x64 compatibility asset selection | Full manual GUI/installer flow and Batch execution under emulation |
| Linux x64/ARM64 | 36 core tests; desktop and extracted-package smoke checks on native Ubuntu runners; settings/details folded initially | Actual publisher app graphical launches on hardware; WSL; varied window sizes and fonts |

Windows native builds: https://github.com/CyberMike81/uLEAPP/actions/runs/40139410888

Mac discovery reads existing Applications bundles and the same selected-install
records used by earlier direct installs. Stable internal tool IDs preserve those
records. Legacy package-manager preferences are not read. The application has no
package-manager execution, setup question, backend toggle, return action or password
helper. Archived source is not part of the app.

Mac checks/downloads select exact official repository URLs and published size and
SHA-256 digests. Installations verify bundle version, architecture, Apple-anchored
Developer ID team N2G83326TZ and Gatekeeper before applying quarantine and atomically
selecting the version. Existing Applications copies are preserved. Native isolated
ALEAPP and Map Downloader integrations exercise real publisher packages; both
passed for this release, without mutating real app folders.

Selection tests verify that a successful newer publication becomes the Launch
selection, a failed duplicate publication preserves it, and a malformed selection
is refused rather than silently used. Launch reads the selected record again; no
package download or installation happens simply from pressing Launch.

Manual cleanup keeps the selected and previous managed versions. Unknown/changed
folders and case files are preserved. Windows requires a successful Recycle Bin
callback and refuses unsupported volume/policy cases; physical failure modes need
manual hardware testing. Linux Trash metadata and failed moves have isolated tests.

Presentation checks cover unchecked/current/update/error pills and prior successful
GitHub-check evidence. Windows tests cover 0/5/7/9 installed tools plus a tenth row.
Mac tests distinguish an installed manual Batch copy from a version-verified one.
Mac visual review covers nine rows, row menus, folded Settings and Details, source
wording and footer actions. Windows/Linux visual coverage remains bounded by the
native packaged checks and desktop smoke tests.

Mac Batch remains manual because the publisher’s current GUI ZIP is ad hoc signed,
not notarized and reports bundle version 0.0.0. It is not automatically installed
or called current. The official identifying icon retains its rights-holder notice;
no new publisher license grant is claimed.

uLEAPP’s own optional update check runs at startup and daily. It selects only
stable public releases and official platform URLs, handles ETag/quota errors and
supports a persisted opt-out plus --no-update-check. Its Download action opens the
matching browser download; it does not self-install.

All public packages are version/architecture checked and covered by SHA256SUMS.
The preview source archive carries a file-level checksum inventory and review
manifest. This release changes audited source and does not inherit a claim that
the independent 0.3.9 audit covers the new code. Mac uLEAPP is ad hoc signed and
not notarized; Windows is unsigned; Linux requires Python 3.10+ and Tk.
