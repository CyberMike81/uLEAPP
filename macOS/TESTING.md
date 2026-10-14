# Validation approach

Reviewed the upstream [iLEAPP build workflow](https://github.com/abrignoni/iLEAPP/blob/master/.github/workflows/test_builds.yml), [RLEAPP build workflow](https://github.com/abrignoni/RLEAPP/blob/main/.github/workflows/test_builds.yml), and the official tap's `tests/test_update_homebrew.sh`. Local copies were checked against the current public workflows; their packaging details differ, so the public workflows are the reference.

The relevant expectation is to execute the built artifact and check its user entry points, rather than count successful compilation as a working app. uLEAPP does not modify LEAPP parsers, forensic input or case reports, so parser regression suites do not validate the updater itself.

| Area | Check |
| --- | --- |
| Update scope | Only the seven named official casks; unmanaged and unrelated apps are skipped |
| Install scope | Individual and bulk missing-app installs; existing apps untouched; unsupported names rejected |
| Setup | Trust before tap; refresh before app work; older Homebrew support |
| Failure handling | An app failure does not stop the other apps; setup failures stop upgrades |
| Preview/check | Preview makes no changes; check mode makes no app upgrades |
| UI status | App/version events map to the right rows; raw details remain available |
| Stop | Finish the current operation and stop before starting another app |
| Built artifact | Run `--version` and `--selfcheck` from inside the app bundle |
| Packaging | Worker and authentication helper executable; icon present; both Mac architectures |
| Licenses | MIT, dependency inventory and reference notices included; original icon geometry |
| Signature | Strict verification of the local ad hoc signature |
| Manual GUI | Launch normally, inspect all rows and controls, exercise check and demo updates |
| Authorization (manual check pending) | Exercise the password helper and cancel path, then inspect status/log output for secret handling |

Run:

```sh
bash tests/test_updater.sh
python3 tests/smoke.py
open uLEAPP.app --args --demo
```

The shell worker has 79 passing offline checks. The optional
`python3 tests/live_homebrew.py` check uses real Homebrew on a Mac with all seven
casks managed, skips preparation/refresh commands and installs nothing. It tests
current metadata and a controlled `--minimum-version` query to exercise the named
outdated exit code without requiring a genuinely outdated app. Its transcript is
`tests/LIVE-HOMEBREW-CHECK.txt`.

The Mac app is exercised on Apple silicon, and the Intel CLI has been run under
Rosetta; that does not establish compatibility on older Intel Macs. Windows has
a separate self-check and user installation/UI test matrix. Public Mac signing
and notarization and maintainer acceptance remain later review steps.
