# Publisher application icons

These are the actual icons copied from the installed official Mac applications,
at the user's request. They identify the supported applications, including before
installation. They are not uLEAPP's original artwork and do not imply endorsement.
`PROVENANCE.json` records source paths, versions, hashes and conversion details.
`tools/extract_app_icons.py` reproduces extraction from those installed apps.

The six parser icons keep their projects' MIT terms and attribution; full license
copies are in `licenses/`. ALEAPP, iLEAPP, RLEAPP, VLEAPP and DLEAPP's source ICNS
Git blob hashes match the published MIT-licensed files exactly:

- ALEAPP: `v2026.4.3/assets/icon.icns`
- iLEAPP: `v2026.4.4/assets/icon.icns` (the installed bundle declares 2026.4.5,
  but its icon is byte-identical to the published 2026.4.4 icon).
- RLEAPP, VLEAPP, DLEAPP: `v2026.4.3/assets/icon.icns`
- GLEAPP: extracted from official 2026.5.4; publisher artwork is part of its
  MIT-licensed project. Its source logo is `docs/images/gleapp-logo.svg`.

LAVA's icon is LEAPPs' publisher artwork, governed separately from uLEAPP's MIT
license; see `licenses/LAVA-EULA.txt`. That EULA reserves ownership of assets and
does not clearly grant standalone logo redistribution. The maintainer chose to include this identifying icon for publisher review.
The preview retains its unmodified EULA and provenance; it asserts no standalone
artwork permission grant and does not relicense the icon under MIT.

Batch LEAPP uses the official v1.2.0 application icon, converted from its ICNS.
Its original rights are retained; see licenses/Batch-LEAPP.txt. Map Downloader
uses its MIT-licensed v0.2.0 application icon; see licenses/GLEAPP-MapDownloader.txt.
