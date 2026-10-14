#!/usr/bin/env python3
"""Copy publisher icons from installed Mac apps for the uLEAPP catalog.

Preserves a 256px PNG frame when present; ImageIO converts LAVA's ICNS frame.
Publisher artwork keeps its own license; see assets/tool-icons/README.md.
SPDX-License-Identifier: MIT
"""
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import subprocess

root = Path(__file__).resolve().parents[1]
destination = root / "assets/tool-icons"
destination.mkdir(parents=True, exist_ok=True)
manifest = []
for name in ["LAVA", "ALEAPP", "iLEAPP", "RLEAPP", "VLEAPP", "DLEAPP", "GLEAPP"]:
    app = Path("/Applications") / (name + ".app")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    icon = app / "Contents/Resources" / info["CFBundleIconFile"]
    if not icon.suffix:
        icon = icon.with_suffix(".icns")
    raw = icon.read_bytes()
    if raw[:4] != b"icns" or struct.unpack(">I", raw[4:8])[0] != len(raw):
        raise ValueError(f"Invalid ICNS source: {name}")
    png = None
    offset = 8
    while offset + 8 <= len(raw):
        size = struct.unpack(">I", raw[offset + 4:offset + 8])[0]
        if size < 8 or offset + size > len(raw):
            raise ValueError(f"Invalid ICNS frame: {name}")
        frame = raw[offset + 8:offset + size]
        if frame.startswith(b"\x89PNG\r\n\x1a\n") and struct.unpack(">II", frame[16:24]) == (256, 256):
            png = frame
            break
        offset += size
    target = destination / (name.lower() + ".png")
    if png is not None:
        target.write_bytes(png)
    else:
        subprocess.run(["/usr/bin/sips", "-s", "format", "png", "-z", "256", "256", str(icon), "--out", str(target)],
                       check=True, capture_output=True)
    manifest.append({
        "tool": name, "installed_bundle_version": info.get("CFBundleShortVersionString"),
        "source": str(icon), "source_icns_sha256": hashlib.sha256(raw).hexdigest(),
        "source_git_blob_sha1": hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest(),
        "png": target.name, "png_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "conversion": "unchanged embedded PNG frame" if png is not None else "ICNS to 256px PNG using macOS ImageIO",
        "license_reference": "licenses/LAVA-EULA.txt" if name == "LAVA" else "licenses/" + name + ".txt",
    })
    print(name + ": copied the actual installed application icon")
(destination / "PROVENANCE.json").write_text(json.dumps(manifest, indent=2) + "\n")
