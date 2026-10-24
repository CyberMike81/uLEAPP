# uLEAPP license and dependency inventory

Reviewed 2026-10-14. uLEAPP's original source, scripts, tests and original icon
artwork are MIT licensed; see `LICENSE`. Idea by Michael Littrell,
[@CyberMike81](https://github.com/CyberMike81). This credit is for the idea, not
an assertion that Michael authored or owns the code. The original project
license carries no named copyright ownership claim.

This license covers uLEAPP, not the operating systems or the LEAPP apps it manages.
There are no third-party application packages, copied upstream updater scripts,
embedded web frameworks, analytics SDKs or font files in uLEAPP's source. The
native GUI uses platform APIs. No LEAPP application executables or release
archives are bundled. Publisher identification icons are described below.

## Application and build dependencies

| Component | License | How used | Distribution handling |
| --- | --- | --- | --- |
| Swift compiler and standard library | Apache-2.0 with Runtime Library Exception | Mac compiler; system runtime and compiler-generated compatibility code | `licenses/Swift.txt`; exception applies to compiler-embedded runtime portions |
| Homebrew 7.0.9 | BSD-2-Clause | Existing user's external package manager, invoked by the Mac worker | Not bundled; reference notice in `licenses/Homebrew.txt` |
| .NET runtime and WPF 10.0.13 | MIT, with separately licensed third-party portions | Windows GUI and self-contained runtime | Exact runtime-pack licenses and notices included under `runtime-notices/`; WPF's matching source-tag third-party notice is included separately |
| .NET SDK | MIT with third-party notices | Build only, downloaded from Microsoft with SHA-512 verification | Not bundled; SDK's notices retained in task-local SDK installation |
| Apple AppKit, SwiftUI, Foundation, Combine, macOS SDK and Apple build utilities | Apple platform/SDK terms, not open source as a whole | Mac system frameworks and development tools | System-provided; no Apple SDK, system framework, font or SF Symbol artwork redistributed |
| Windows OS APIs, Windows SDK/reference assemblies | Microsoft platform/SDK terms, not open source as a whole | Native Windows execution and build targeting | Not bundled as standalone OS/SDK components; runtime-pack notices govern shipped runtime files |
| Parallels Desktop and Windows VM | Proprietary host/testing tools | Local Windows build/test environment only | Not a uLEAPP dependency and not redistributed |
| Bash, curl, Python 3 | GPL-2.0-or-later; curl license; PSF-2.0 and bundled notices, respectively | Host shell, development downloads and local tests | Existing host tools only; no copies included in app packages |

The open-source application licenses above permit this use when their required
notices are retained. Native OS and SDK components remain under their vendors'
terms. Calling an external executable does not copy it into uLEAPP. The inventory
does not claim that every part of macOS, Windows or the development workstation
is open source.

The Windows 0.3.11 builds use Microsoft .NET SDK 10.0.402 and runtime packs
10.0.13. `BUILD-INFO.json` in each Windows platform folder records the actual
SDK, architecture and runtime versions. The desktop pack supplies a MIT
`LICENSE` file; its additional notices are taken from the matching
[WPF v10.0.13 source notice](https://github.com/dotnet/wpf/blob/v10.0.13/THIRD-PARTY-NOTICES.TXT).

## Separately downloaded LEAPP applications

| App | Reviewed release | Upstream license | Source |
| --- | --- | --- | --- |
| iLEAPP | v2026.4.4 | MIT; Alexis Brignoni | [License](https://github.com/abrignoni/iLEAPP/blob/v2026.4.4/LICENSE) |
| ALEAPP | v2026.4.3 | MIT; Alexis Brignoni | [License](https://github.com/abrignoni/ALEAPP/blob/v2026.4.3/LICENSE) |
| RLEAPP | v2026.4.3 | MIT; Alexis Brignoni | [License](https://github.com/abrignoni/RLEAPP/blob/v2026.4.3/LICENSE) |
| VLEAPP | v2026.4.3 | MIT; Alexis Brignoni | [License](https://github.com/abrignoni/VLEAPP/blob/v2026.4.3/LICENSE) |
| DLEAPP | v2026.4.3 | MIT; Alexis Brignoni | [License](https://github.com/abrignoni/DLEAPP/blob/v2026.4.3/LICENSE) |
| GLEAPP | v2026.5.4 | MIT; charpy4n6 and Alexis Brignoni | [License](https://github.com/abrignoni/GLEAPP/blob/v2026.5.4/LICENSE) |
| LAVA | v0.15.0 | LEAPPs freeware EULA; **not open source** | [EULA](https://github.com/leapps-org/LAVA-releases/blob/main/LICENSE) |

Reference copies are under `licenses/`. Downloaded app archives retain their own
license, attribution, runtime and support files. Those apps may include additional
dependencies under their own licenses; uLEAPP does not relicense or repackage them
as part of its own release. A top-level MIT license is not an audit of every
dependency inside another project's binary.

LAVA grants installation and use, with restrictions on modification and
redistribution. Its application is downloaded directly from the publisher;
uLEAPP does not bundle, modify or mirror its executable. Its identifying icon
is included in the community preview build as described below. First-time installation exposes its
license separately; the Windows installer remains interactive. No unattended
acceptance of a third-party EULA is implemented.

The official [Homebrew tap](https://github.com/leapps-org/homebrew-leapps) has no
top-level license declared at this review. uLEAPP invokes its documented Homebrew
commands; it does not vendor or redistribute the tap's code, casks, scripts or
artwork. Any future copying of that repository's code needs a license clarification.

## Artwork and names

The uLEAPP icon is original vector geometry: a bright book, two offset update
arrows and a hand-drawn lowercase `u`. Its source is `macOS/tools/MakeIcon.swift`.
It uses no SF Symbols, font outlines, copied LEAPP logo shapes or stock assets.
The seven supported applications' actual icons are included under
`assets/tool-icons/`, so Windows shows them before installation. The Mac uses
installed app icons when available and the bundled publisher icons otherwise.
These icons retain publisher ownership and their own terms; uLEAPP's MIT grant
does not relicense LAVA artwork. Full provenance and the six parser projects'
license references are in `assets/tool-icons/README.md` and `PROVENANCE.json`.

LAVA's EULA reserves its assets and does not clearly grant standalone icon
redistribution. The maintainer chose to include the identifying icon for publisher review.
The preview includes the unmodified EULA and provenance; no standalone artwork
permission grant is asserted.
SF Symbols used inside the Mac interface are loaded from macOS only.

Apple prohibits SF Symbols in app icons/logos. See
[Apple's SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols).
LEAPP product names identify supported external tools. uLEAPP is a community
project and does not claim official endorsement or ownership of those marks.

## Primary licensing sources

- [Swift license and runtime exception](https://github.com/swiftlang/swift/blob/main/LICENSE.txt)
- [Homebrew 7.0.9 license](https://github.com/Homebrew/brew/blob/7.0.9/LICENSE.txt)
- [.NET runtime license](https://github.com/dotnet/runtime/blob/main/LICENSE.TXT)
- [WPF license](https://github.com/dotnet/wpf/blob/main/LICENSE.TXT)
- [.NET SDK license](https://github.com/dotnet/sdk/blob/main/LICENSE.TXT)
- [Apple Xcode and SDK agreement](https://www.apple.com/legal/sla/docs/xcode.pdf)
- [GNU Bash license](https://www.gnu.org/software/bash/manual/html_node/Copying.html)
- [curl license](https://curl.se/docs/copyright.html)
- [Python license](https://docs.python.org/3/license.html)

## Release checks

Before public release, verify the actual shipped runtime versions and notices,
the absence of SDKs/upstream application executables, publisher-icon permissions, and the source
dependency inventory. Keep this file, `LICENSE`, `licenses/` and Windows runtime
notices in each platform package. Recheck this inventory whenever a dependency,
asset, upstream license or packaging method changes.

## Mac direct-install publisher identity

Direct Mac installs require an Apple-anchored Developer ID signature from team
`N2G83326TZ` (the LEAPP publisher), a successful Gatekeeper execution assessment,
and the published SHA-256 digest. uLEAPP applies quarantine before selecting the
app. A publisher team change requires a reviewed uLEAPP update; ad hoc signatures
and other teams are refused. Windows publisher builds remain unsigned.

Companion tools: Batch LEAPP and GLEAPP Map Downloader are downloaded directly from
their official abrignoni GitHub releases on demand; their programs are not bundled.
Map Downloader artwork is MIT licensed; see licenses/GLEAPP-MapDownloader.txt.
The official Batch LEAPP icon identifies the supported application. Its artwork
remains with the original rights holders and is not relicensed under uLEAPP’s MIT
license. See licenses/Batch-LEAPP.txt for the pinned source and attribution.
