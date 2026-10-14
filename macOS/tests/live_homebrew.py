#!/usr/bin/env python3
"""Read-only integration checks for a Mac with all seven LEAPP casks installed.

Uses real Homebrew for listing/checking apps. Skips trust/tap/update and uses
Homebrew's minimum-version query to exercise exit 1 without changing any app.
Requires a Homebrew version supporting `outdated --minimum-version`.
SPDX-License-Identifier: MIT
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
brew = shutil.which("brew") or next((p for p in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] if Path(p).is_file()), None)
if brew is None:
    raise SystemExit("Homebrew is required for this optional integration check.")
transcript = []
with tempfile.TemporaryDirectory(prefix="uleapp-live-brew-") as temporary:
    adapter = Path(temporary) / "brew"
    adapter.write_text("""#!/bin/bash
case "$1" in
  trust|tap|update) printf 'Read-only integration: skipped Homebrew preparation (%s).\\n' "$1" >&2; exit 0 ;;
  outdated)
    if [[ "${ULEAPP_TEST_MINIMUM:-0}" == 1 && "${!#}" == leapps-org/leapps/ileapp-gui ]]; then
      exec REAL_BREW "$@" --minimum-version=9999.0.0
    fi
    exec REAL_BREW "$@" ;;
  list|help) exec REAL_BREW "$@" ;;
  *) printf 'Blocked command: %s\\n' "$1" >&2; exit 99 ;;
esac
""".replace("REAL_BREW", shlex.quote(brew)))
    adapter.chmod(0o755)
    for minimum in [False, True]:
        label = "Controlled minimum-version query for iLEAPP (not a published update)" if minimum else "Current official cask metadata"
        environment = dict(os.environ, PATH=temporary + ":" + os.environ["PATH"],
                           ULEAPP_EVENTS="1", HOMEBREW_NO_AUTO_UPDATE="1",
                           ULEAPP_TEST_MINIMUM="1" if minimum else "0")
        result = subprocess.run(["/bin/bash", str(root / "scripts/LEAPP Updater.command"), "--check"],
                                env=environment, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=120)
        output = label + "\n" + result.stdout + result.stderr
        versions = [line for line in result.stdout.splitlines() if line.startswith("ULEAPP\tversion\t")]
        states = [line for line in result.stdout.splitlines() if line.startswith("ULEAPP\tapp\t") and "\tchecking\t" not in line]
        assert result.returncode == 0, output
        assert len(versions) == 7, "This check requires all seven apps managed by Homebrew.\n" + output
        assert len(states) == 7 and all("\tcurrent\t" in line or "\tavailable\t" in line for line in states), output
        if minimum:
            assert "ULEAPP\tapp\tileapp-gui\tavailable\tUpdate available" in result.stdout, output
        output += f"Verified: {len(versions)} installed versions and {len(states)} final statuses; exit {result.returncode}.\n"
        transcript.append(output)
output = "Live Homebrew integration: trust/tap/update skipped; no apps were changed.\n\n" + "\n".join(transcript)
(root / "tests/LIVE-HOMEBREW-CHECK.txt").write_text(output)
print(output)
