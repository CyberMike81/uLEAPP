#!/bin/bash
# Exercise the desktop updater with a fake brew; no network or app changes.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
cat > "$scratch/bin/brew" <<'BREW'
#!/bin/bash
set -u
printf '%s\n' "$*" >> "$LEAPP_TEST_DIR/trace"
case "$1" in
  help)
    case "${LEAPP_TEST_MODE:-modern}" in
      legacy) exit 1 ;;
      gains-trust) [[ -e "$LEAPP_TEST_DIR/refreshed" ]]; exit $? ;;
    esac
    exit 0
    ;;
  trust|tap|update)
    if [[ "${LEAPP_TEST_FAIL:-}" == "$1" ]]; then
      printf 'Simulated %s error\n' "$1" >&2
      exit 1
    fi
    [[ "$1" != update ]] || touch "$LEAPP_TEST_DIR/refreshed"
    ;;
  list)
    [[ "${LEAPP_TEST_FAIL:-}" != list ]] || exit 1
    if [[ "$*" == *--versions* ]]; then
      token="${!#}"
      # Real Homebrew version listings reject tap-qualified tokens.
      [[ "$token" != */* ]] || exit 1
      if [[ "${LEAPP_TEST_MODE:-}" == version-prefix ]]; then
        printf '%s-helper 99.0.0\n' "$token"
      fi
      if [[ "${LEAPP_TEST_MODE:-}" != version-prefix-only ]]; then
        printf '%s 1.0.0\n' "$token"
      else
        printf '%s-helper 99.0.0\n' "$token"
      fi
    else
      cat "$LEAPP_TEST_DIR/installed"
    fi
    ;;
  outdated)
    token="${!#}"
    if [[ "${LEAPP_TEST_FAIL:-}" == "outdated:$token" ]]; then
      printf 'Simulated outdated error for %s\n' "$token" >&2
      exit 1
    fi
    if [[ "$token" == leapps-org/leapps/ileapp-gui ]]; then
      case "${LEAPP_TEST_MODE:-}" in
        unexpected-outdated) printf 'ileapp-gui-helper\n'; exit 0 ;;
        failed-outdated-with-output) printf 'ileapp-gui\n'; exit 2 ;;
        outdated-zero) printf 'ileapp-gui\n'; exit 0 ;;
      esac
      printf '%s\n' ileapp-gui
      exit 1
    fi
    ;;
  upgrade|install)
    [[ "${LEAPP_TEST_FAIL:-}" != "${!#}" ]] || exit 1
    if [[ "$1" == install ]]; then
      token="${!#}"
      printf '%s\n' "${token##*/}" >> "$LEAPP_TEST_DIR/installed"
    fi
    if [[ "${LEAPP_TEST_MODE:-}" == stop-after-one ]]; then
      touch "$ULEAPP_CANCEL_FILE"
    fi
    ;;
  *) printf 'Unexpected command: %s\n' "$*" >&2; exit 99 ;;
esac
BREW
chmod 755 "$scratch/bin/brew"
cat > "$scratch/bin/release-checker" <<'CHECKER'
#!/bin/bash
if [[ "$1" == --direct-tool-version ]]; then
  case "${LEAPP_TEST_MODE:-}:$2" in
    direct-managed:aleapp-gui) printf '2026.4.4\n'; exit 0 ;;
    direct-newer:aleapp-gui) printf '2026.4.3\n'; exit 0 ;;
    direct-error:aleapp-gui) exit 1 ;;
  esac
  exit 3
fi
case "${LEAPP_TEST_MODE:-}:$2" in
  direct-managed:aleapp-gui) [[ "$3" == 2026.4.4 ]] || exit 1; printf '2026.4.4\n'; exit 0 ;;
  direct-newer:aleapp-gui) [[ "$3" == 2026.4.3 ]] || exit 1; printf '2026.4.4\n'; exit 10 ;;
  upstream-behind:aleapp-gui) printf '2026.4.4\n'; exit 10 ;;
  upstream-failed:aleapp-gui) printf 'GitHub unavailable\n' >&2; exit 1 ;;
esac
printf '1.0.0\n'
CHECKER
chmod 755 "$scratch/bin/release-checker"


passed=0
failed=0
expect() {
  local description=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$description"
    passed=$((passed + 1))
  else
    printf 'FAIL - %s\n' "$description"
    failed=$((failed + 1))
  fi
}
new_case() {
  case_dir="$scratch/$1"
  mkdir -p "$case_dir"
  printf '%s\n' lava aleapp-gui ileapp-gui rleapp-gui vleapp-gui dleapp-gui gleapp openscad > "$case_dir/installed"
  : > "$case_dir/trace"
  mode=modern
  failure=''
  events=0
  cancel_file=''
}
run_case() {
  status=0
  env PATH="$scratch/bin:$PATH" LEAPP_TEST_DIR="$case_dir" \
    LEAPP_TEST_MODE="$mode" LEAPP_TEST_FAIL="$failure" \
    ULEAPP_RELEASE_CHECKER="$scratch/bin/release-checker" \
    ULEAPP_EVENTS="$events" ULEAPP_CANCEL_FILE="$cancel_file" \
    /bin/bash "$root/scripts/LEAPP Updater.command" "$@" \
    > "$case_dir/output" 2>&1 < /dev/null || status=$?
}
upgrade_count() {
  [[ $(grep -c '^upgrade ' "$case_dir/trace") -eq "$1" ]]
}
install_count() {
  [[ $(grep -c '^install ' "$case_dir/trace") -eq "$1" ]]
}
no_mutations() {
  ! grep -Eq '^(trust|tap|update|upgrade|install|reinstall|uninstall)( |$)' "$case_dir/trace"
}

new_case all-installed
run_case
expect 'all seven installed apps succeed' test "$status" -eq 0
expect 'all seven apps are checked for upgrades' upgrade_count 7
expect 'trust, tap and refresh run before upgrades' diff -u \
  <(printf '%s\n' 'help trust' 'trust leapps-org/leapps' 'tap leapps-org/leapps' update 'list --cask -1') \
  <(head -n 5 "$case_dir/trace")
expect 'every app comes from the official tap' test \
  "$(grep -c '^upgrade --cask --greedy leapps-org/leapps/' "$case_dir/trace")" -eq 7
expect 'unrelated apps are not upgraded' test \
  "$(grep -c openscad "$case_dir/trace")" -eq 0

new_case subset
printf '%s\n' leapps-org/leapps/ileapp-gui openscad > "$case_dir/installed"
run_case
expect 'a subset of installed apps succeeds' test "$status" -eq 0
expect 'qualified installed names are recognized' upgrade_count 1
expect 'missing apps are skipped without installing them' grep -Fq '1 apps ready; 0 failed; 6 skipped' "$case_dir/output"

new_case one-failure
failure=leapps-org/leapps/lava
run_case
expect 'an app failure produces a failure status' test "$status" -eq 1
expect 'one failure does not prevent the other apps updating' upgrade_count 7
expect 'the summary identifies the failed app' grep -Fq 'Needs attention: LAVA' "$case_dir/output"

for setup_failure in trust tap update list; do
  new_case "failed-$setup_failure"
  failure=$setup_failure
  run_case
  expect "$setup_failure failure stops the run" test "$status" -eq 1
  expect "$setup_failure failure prevents app upgrades" upgrade_count 0
done

new_case legacy
mode=legacy
run_case
expect 'older Homebrew without trust is supported' test "$status" -eq 0
expect 'legacy Homebrew still updates all seven apps' upgrade_count 7
expect 'legacy Homebrew is not sent an unsupported trust command' test \
  "$(grep -c '^trust ' "$case_dir/trace")" -eq 0

new_case gains-trust
mode=gains-trust
run_case
expect 'Homebrew gaining trust during its update is supported' test "$status" -eq 0
expect 'new trust support is used before the installed apps are read' diff -u \
  <(printf '%s\n' 'help trust' 'tap leapps-org/leapps' update 'help trust' 'trust leapps-org/leapps' 'list --cask -1') \
  <(head -n 6 "$case_dir/trace")

new_case preview
run_case --dry-run
expect 'preview succeeds' test "$status" -eq 0
expect 'preview invokes no mutating brew commands' no_mutations
expect 'preview shows all seven planned upgrades' test \
  "$(grep -c 'Would run:.* upgrade --cask' "$case_dir/output")" -eq 7
events=1
run_case --dry-run
expect 'preview never reports that an app was updated' test "$(grep -c $'^ULEAPP\t' "$case_dir/output")" -eq 0

new_case invalid-argument
run_case --unexpected
expect 'unknown options are rejected' test "$status" -eq 2
expect 'unknown options cause no Homebrew changes' no_mutations

new_case check-only
events=1
run_case --check
expect 'check mode succeeds' test "$status" -eq 0
expect 'check mode does not upgrade apps' upgrade_count 0
expect 'check mode finds the available update' grep -Fq '1 updates available' "$case_dir/output"
expect 'the GUI receives the correct app status' grep -Fq $'ULEAPP\tapp\tileapp-gui\tavailable\tUpdate available' "$case_dir/output"
expect 'the GUI receives installed versions' test "$(grep -c $'^ULEAPP\tversion\t' "$case_dir/output")" -eq 7
expect 'version queries use bare cask tokens' test "$(grep -c '^list --cask --versions leapps-org/' "$case_dir/trace")" -eq 0
expect 'check requests names without verbose formatting' test "$(grep -c '^outdated --cask --greedy --quiet ' "$case_dir/trace")" -eq 7

new_case version-prefix
mode=version-prefix
events=1
run_case --check
expect 'prefix matches do not replace exact installed versions' test "$(grep -c $'^ULEAPP\tversion\t.*\t1.0.0$' "$case_dir/output")" -eq 7
expect 'unrelated prefix versions never reach the GUI' test "$(grep -c $'^ULEAPP\tversion\t.*99.0.0' "$case_dir/output")" -eq 0

new_case version-prefix-only
mode=version-prefix-only
events=1
run_case --check
expect 'prefix-only versions are not attributed to supported apps' test "$(grep -c $'^ULEAPP\tversion\t' "$case_dir/output")" -eq 0

new_case outdated-zero
mode=outdated-zero
run_case --check
expect 'older successful named-outdated responses are supported' test "$status" -eq 0
expect 'an exact outdated token is counted with exit zero' grep -Fq '1 updates available' "$case_dir/output"

for invalid_check in unexpected-outdated failed-outdated-with-output; do
  new_case "$invalid_check"
  mode=$invalid_check
  events=1
  run_case --check
  expect "$invalid_check is reported as a check failure" test "$status" -eq 1
  expect "$invalid_check is not reported as an available update" test "$(grep -c $'^ULEAPP\tapp\tileapp-gui\tavailable\t' "$case_dir/output")" -eq 0
done

new_case check-failure
failure=outdated:leapps-org/leapps/lava
events=1
run_case --check
expect 'a check failure is reported' test "$status" -eq 1
expect 'the other apps are still checked' test "$(grep -c '^outdated ' "$case_dir/trace")" -eq 7
expect 'the GUI receives the check failure' grep -Fq $'ULEAPP\tapp\tlava\tfailed\t' "$case_dir/output"
expect 'a genuine exit-one check error remains visible' grep -Fq 'Simulated outdated error' "$case_dir/output"
expect 'a genuine exit-one error is not counted as an update' grep -Fq '1 updates available; 1 failed' "$case_dir/output"

new_case stop-after-operation
mode=stop-after-one
events=1
cancel_file="$case_dir/stop"
run_case
expect 'a requested stop produces a stopped status' test "$status" -eq 130
expect 'stopping finishes the active app but starts no further upgrades' upgrade_count 1
expect 'the GUI receives the stopped status' grep -Fq $'ULEAPP\tphase\t\tstopped\t' "$case_dir/output"

new_case install-one
printf '%s\n' ileapp-gui openscad > "$case_dir/installed"
events=1
run_case --install lava
expect 'one missing app installs successfully' test "$status" -eq 0
expect 'one-app install affects only the requested app' install_count 1
expect 'install uses adoption without forced replacement' grep -Fxq 'install --cask --adopt leapps-org/leapps/lava' "$case_dir/trace"
expect 'install does not upgrade existing apps' upgrade_count 0
expect 'the GUI receives the installing state' grep -Fq $'ULEAPP\tapp\tlava\tinstalling\t' "$case_dir/output"
expect 'the GUI receives the newly installed version' grep -Fq $'ULEAPP\tversion\tlava\t\t1.0.0' "$case_dir/output"

new_case install-existing
run_case --install lava
expect 'installing an already managed app succeeds' test "$status" -eq 0
expect 'an existing app is not reinstalled' install_count 0
expect 'an existing app is not upgraded by install' upgrade_count 0

new_case install-missing
printf '%s\n' lava ileapp-gui openscad > "$case_dir/installed"
run_case --install-missing
expect 'bulk missing-app installation succeeds' test "$status" -eq 0
expect 'only the five missing apps are installed' install_count 5
expect 'bulk install does not upgrade existing apps' upgrade_count 0
expect 'unrelated apps are never installed' test "$(grep -c openscad "$case_dir/trace")" -eq 0

for invalid in unsupported missing-argument excess-argument; do
  new_case "install-invalid-$invalid"
  case "$invalid" in
    unsupported) run_case --install openscad ;;
    missing-argument) run_case --install ;;
    excess-argument) run_case --install lava extra ;;
  esac
  expect "$invalid is rejected before Homebrew runs" test "$status" -eq 2
  expect "$invalid does not mutate apps" no_mutations
done

new_case install-failure
: > "$case_dir/installed"
failure=leapps-org/leapps/lava
run_case --install-missing
expect 'installation failure is reported' test "$status" -eq 1
expect 'one installation failure does not stop the remaining apps' install_count 7
expect 'installation failure identifies the affected app' grep -Fq 'Needs attention: LAVA' "$case_dir/output"

new_case stop-during-install
: > "$case_dir/installed"
mode=stop-after-one
cancel_file="$case_dir/stop"
run_case --install-missing
expect 'stop during installation is reported safely' test "$status" -eq 130
expect 'the current installation finishes before stopping' install_count 1
expect 'stop never starts app upgrades' upgrade_count 0

new_case upstream-behind
mode=upstream-behind
events=1
run_case --check
expect 'stale Homebrew with a newer GitHub release is reported successfully' test "$status" -eq 0
expect 'stale Homebrew is pending rather than current' grep -Fq $'ULEAPP\tapp\taleapp-gui\tpending\t' "$case_dir/output"
expect 'pending upstream version is exposed to the interface' grep -Fq $'ULEAPP\tupstream\taleapp-gui\t\t2026.4.4' "$case_dir/output"
expect 'pending release has an official download link' grep -Fq 'https://github.com/abrignoni/ALEAPP/releases/latest' "$case_dir/output"
run_case
expect 'a successful brew upgrade cannot hide a newer GitHub release' grep -Fq $'ULEAPP\tapp\taleapp-gui\tpending\t' "$case_dir/output"

new_case upstream-failed
mode=upstream-failed
events=1
run_case --check
expect 'GitHub lookup failure is not reported as current' test "$status" -eq 1
expect 'GitHub lookup failure marks the app for attention' grep -Fq $'ULEAPP\tapp\taleapp-gui\tfailed\t' "$case_dir/output"

new_case direct-managed
mode=direct-managed
events=1
run_case --check
expect 'a direct installation reports its recorded version instead of Homebrew' grep -Fq $'ULEAPP\tversion\taleapp-gui\t\t2026.4.4' "$case_dir/output"
expect 'a current direct installation is recognized' grep -Fq $'ULEAPP\tapp\taleapp-gui\tcurrent\t' "$case_dir/output"
run_case
expect 'Homebrew does not replace or downgrade the direct copy' upgrade_count 6
printf '%s\n' ileapp-gui > "$case_dir/installed"
run_case --check
expect 'direct installs remain managed without a Homebrew receipt' grep -Fq $'ULEAPP\tapp\taleapp-gui\tcurrent\t' "$case_dir/output"

new_case direct-newer
mode=direct-newer
events=1
run_case --check
expect 'a newer release for a direct install is offered' grep -Fq $'ULEAPP\tapp\taleapp-gui\tpending\t' "$case_dir/output"

new_case direct-error
mode=direct-error
events=1
run_case --check
expect 'an unreadable direct record is not called up to date' test "$status" -eq 1
expect 'an unreadable direct record needs attention' grep -Fq $'ULEAPP\tapp\taleapp-gui\tfailed\t' "$case_dir/output"

printf '\n%s passed; %s failed.\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
