#!/usr/bin/env python3
"""Create and verify a local source-and-app review archive on macOS.

SPDX-License-Identifier: MIT
Uses Python's standard library and the system ditto/codesign/lipo utilities.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import stat
import struct
import subprocess
import tempfile
import zipfile


EXCLUDED = {"build", "bin", "obj", "dist", ".git", ".DS_Store", "__pycache__"}


def ignore(_directory: str, names: list[str]) -> set[str]:
    return {name for name in names if name in EXCLUDED or name.startswith("._")}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(*arguments: str | Path) -> str:
    result = subprocess.run([str(a) for a in arguments], capture_output=True,
                            text=True, timeout=90)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()


def verify(project: Path) -> tuple[str, dict[str, dict]]:
    mac = project / "macOS/uLEAPP.app"
    with (mac / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    version = info["CFBundleShortVersionString"]
    if info.get("NSHumanReadableCopyright"):
        raise ValueError("The Mac app still carries an ownership metadata statement.")
    if info.get("CFBundleIdentifier") != "org.uleapp.updater":
        raise ValueError("Unexpected Mac app identifier.")
    if (mac / "Contents/Resources/LICENSE").read_bytes() != (project / "LICENSE").read_bytes():
        raise ValueError("The Mac app's project license differs from the repository license.")
    executable = mac / "Contents/MacOS/uLEAPP"
    if run(executable, "--version") != f"uLEAPP {version}":
        raise ValueError("The Mac version differs from its bundle metadata.")
    if set(run("/usr/bin/lipo", "-archs", executable).split()) != {"arm64", "x86_64"}:
        raise ValueError("The Mac build is not universal.")
    run("/usr/bin/codesign", "--verify", "--strict", "--deep", mac)
    if "self-check passed" not in run(executable, "--selfcheck"):
        raise ValueError("The packaged Mac self-check did not pass.")
    for name in [p.stem for p in sorted((project / "assets/tool-icons").glob("*.png"))]:
        if (mac / f"Contents/Resources/tool-icons/{name}.png").read_bytes() != (project / f"assets/tool-icons/{name}.png").read_bytes():
            raise ValueError(f"The Mac catalog icon differs from its source: {name}")

    artifacts: dict[str, dict] = {
        "macOS": {"version": version, "executable": "macOS/uLEAPP.app/Contents/MacOS/uLEAPP",
                  "sha256": sha256(executable), "architectures": ["arm64", "x86_64"]}
    }
    for platform, rid, machine in [("Windows-ARM64", "win-arm64", 0xAA64),
                                   ("Windows-x64", "win-x64", 0x8664)]:
        folder = project / platform
        binary = folder / "uLEAPP.exe"
        with binary.open("rb") as stream:
            stream.seek(0x3C)
            pe_offset = struct.unpack("<I", stream.read(4))[0]
            stream.seek(pe_offset)
            if stream.read(4) != b"PE\0\0" or struct.unpack("<H", stream.read(2))[0] != machine:
                raise ValueError(f"Wrong executable architecture in {platform}.")
        build = json.loads((folder / "BUILD-INFO.json").read_text(encoding="utf-8-sig"))
        if build["AppVersion"] != version or build["Architecture"] != rid:
            raise ValueError(f"Unexpected build metadata in {platform}.")
        for name in ["LICENSE", "THIRD-PARTY-NOTICES.md", "licenses/LAVA-EULA.txt", "artwork-notices/README.md", "artwork-notices/PROVENANCE.json"]:
            if not (folder / name).is_file():
                raise ValueError(f"Missing notice in {platform}: {name}")
        if (folder / "LICENSE").read_bytes() != (project / "LICENSE").read_bytes():
            raise ValueError(f"Project license mismatch in {platform}.")
        if len(list((folder / "runtime-notices").rglob("LICENSE*"))) != 2:
            raise ValueError(f"Missing exact runtime licenses in {platform}.")
        if len(list((folder / "runtime-notices").rglob("THIRD-PARTY-NOTICES.TXT"))) != 2:
            raise ValueError(f"Missing runtime third-party notices in {platform}.")
        transcript = (folder / "SELF-CHECK.txt").read_text(errors="replace")
        check_result = re.search(r"self-check passed: (\d+) checks\. No installed apps were changed\.", transcript)
        if f"uLEAPP {version} self-check" not in transcript or check_result is None or int(check_result[1]) < 222:
            raise ValueError(f"The recorded Windows self-check is missing in {platform}.")
        artifacts[platform] = {"version": version, "executable": f"{platform}/uLEAPP.exe",
                               "sha256": sha256(binary), "build": build,
                               "self_checks": int(check_result[1]),
                               "test_environment": "Windows 11 ARM64; x64 uses emulation"}
    return version, artifacts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True, help="Built uLEAPP project folder")
    parser.add_argument("--output", type=Path, required=True, help="Destination for review ZIP and checksum")
    args = parser.parse_args()
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version, original_artifacts = verify(project)

    with tempfile.TemporaryDirectory(prefix="uleapp-review-") as temporary:
        temporary_root = Path(temporary)
        stage = temporary_root / f"uLEAPP-{version}"
        stage.mkdir()
        for name in ["README.md", "LICENSE", "THIRD-PARTY-NOTICES.md", "VALIDATION.md", "AUDIT-RESPONSE.md", ".gitignore"]:
            shutil.copy2(project / name, stage / name)
        for name in ["assets", "licenses", "Windows", "Windows-ARM64", "Windows-x64", "tools"]:
            shutil.copytree(project / name, stage / name, ignore=ignore)
        # Keep macOS app metadata out of ZIP extra fields; retain executable modes.
        shutil.copytree(project / "macOS", stage / "macOS",
                        ignore=lambda directory, names: ignore(directory, names) | {"uLEAPP.app"})
        run("/usr/bin/ditto", "--norsrc", project / "macOS/uLEAPP.app", stage / "macOS/uLEAPP.app")
        _, staged_artifacts = verify(stage)
        if staged_artifacts != original_artifacts:
            raise ValueError("An artifact changed while staging the review package.")
        manifest = {"version": version, "publication": "local review only",
                    "artifacts": staged_artifacts}
        (stage / "REVIEW-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
        files = sorted(path for path in stage.rglob("*") if path.is_file())
        for file in stage.rglob("*"):
            if file.is_symlink():
                raise ValueError(f"Unexpected symbolic link in the review package: {file.name}")
        checksums = "".join(f"{sha256(file)}  {file.relative_to(stage).as_posix()}\n" for file in files)
        (stage / "SHA256SUMS.txt").write_text(checksums)
        archive = output / f"uLEAPP-{version}-review.zip"
        provisional = output / f".uLEAPP-{version}-review.tmp.zip"
        try:
            with zipfile.ZipFile(provisional, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as package:
                for file in sorted(stage.rglob("*")):
                    if file.is_file():
                        package.write(file, file.relative_to(temporary_root).as_posix())
            with zipfile.ZipFile(provisional) as package:
                if package.testzip() is not None:
                    raise ValueError("ZIP integrity verification failed.")
                executable_name = f"{stage.name}/macOS/uLEAPP.app/Contents/MacOS/uLEAPP"
                if not (package.getinfo(executable_name).external_attr >> 16) & stat.S_IXUSR:
                    raise ValueError("The ZIP lost the Mac executable permission.")
            extracted = temporary_root / "roundtrip"
            extracted.mkdir()
            run("/usr/bin/ditto", "-x", "-k", provisional, extracted)
            restored_version, restored_artifacts = verify(extracted / stage.name)
            if restored_version != version or restored_artifacts != original_artifacts:
                raise ValueError("The extracted archive differs from the tested artifacts.")
            # A separate Intel CLI check verifies the copied universal slice under Rosetta.
            if "self-check passed" not in run("/usr/bin/arch", "-x86_64", extracted / executable_name, "--selfcheck"):
                raise ValueError("The extracted Intel CLI self-check did not pass.")
            provisional.replace(archive)
        finally:
            provisional.unlink(missing_ok=True)
        digest = sha256(archive)
        (output / f"{archive.name}.sha256").write_text(f"{digest}  {archive.name}\n")
        print(f"Verified review archive: {archive.name}")
        print("Mac native/Intel CLI, signatures, executable modes, Windows architectures and all notices verified after extraction.")
        print(f"Archive size: {archive.stat().st_size / (1024 * 1024):.1f} MiB")


if __name__ == "__main__":
    main()
