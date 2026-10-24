#!/usr/bin/env python3
"""Run the built app and verify its packaging, following LEAPP's build-smoke approach."""
import pathlib
import plistlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parents[1]
app = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "uLEAPP.app"
binary = app / "Contents/MacOS/uLEAPP"

def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=40)
    if result.returncode:
        raise AssertionError(f"{' '.join(map(str, args))}\n{result.stdout}\n{result.stderr}")
    return result.stdout.strip()

with (app / "Contents/Info.plist").open("rb") as stream:
    metadata = plistlib.load(stream)
assert metadata["CFBundleIdentifier"] == "org.uleapp.updater"
assert metadata["CFBundleExecutable"] == binary.name
assert metadata["LSMinimumSystemVersion"] == "13.0"
assert run(str(binary), "--version") == f"uLEAPP {metadata['CFBundleShortVersionString']}"
print("ok - the built executable reports its packaged version")
assert "self-check passed" in run(str(binary), "--selfcheck")
print("ok - official release selection, icons and interface state pass self-check")
for name in ["LEAPP Updater.command", "askpass.sh"]:
    assert not (app / "Contents/Resources" / name).exists()
print("ok - retired package-manager and password helpers are absent")
assert set(run("/usr/bin/lipo", "-archs", str(binary)).split()) == {"arm64", "x86_64"}
print("ok - Apple silicon and Intel binaries are included")
run("/usr/bin/codesign", "--verify", "--strict", "--deep", "--verbose=2", str(app))
print("ok - the local app signature and resources verify")
print("Packaged app smoke checks passed. This does not confirm public signing or notarization.")
