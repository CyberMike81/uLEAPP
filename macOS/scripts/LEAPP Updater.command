#!/bin/bash
# Double-click this file in Finder to update your installed LEAPP apps.
# Package names: https://leapps.org/releases
# Official tap: https://github.com/leapps-org/homebrew-leapps
# Compatible with the Bash version supplied with macOS.
# SPDX-License-Identifier: MIT

set -u
set -o pipefail

finish() {
  local result=$?
  trap - EXIT
  if [[ -t 0 ]]; then
    printf '\nPress Return to close this window...'
    IFS= read -r _ || true
  fi
  exit "$result"
}
trap finish EXIT
trap 'printf "\nUpdate cancelled.\n"; exit 130' INT
trap 'printf "\nUpdate stopped.\n"; exit 143' TERM

preview=0
check_only=0
install_missing=0
install_target=''
case "${1:-}" in
  '') ;;
  --dry-run) preview=1 ;;
  --check) check_only=1 ;;
  --install-missing) install_missing=1 ;;
  --install)
    if [[ $# -ne 2 ]]; then
      printf 'Use --install followed by one LEAPP cask name.\n'
      exit 2
    fi
    install_target="$2"
    case "$install_target" in
      lava|aleapp-gui|ileapp-gui|rleapp-gui|vleapp-gui|dleapp-gui|gleapp) ;;
      *) printf 'This is not a supported LEAPP cask: %s\n' "$install_target"; exit 2 ;;
    esac
    ;;
  --help|-h)
    printf '%s\n' \
      'LEAPP Updater' \
      'Close your LEAPP apps, then double-click this file to update them.' \
      'Updates: LAVA, ALEAPP, iLEAPP, RLEAPP, VLEAPP, DLEAPP, GLEAPP.' \
      'Updates only apps already installed through Homebrew.' \
      'Other apps are skipped and listed in the summary.' \
      'Use --check to refresh Homebrew and check without upgrading apps.' \
      'Use --install CASK to install one missing LEAPP app.' \
      'Use --install-missing to install the missing apps without upgrading existing ones.' \
      'Use --dry-run in Terminal to preview without making changes.'
    exit 0
    ;;
  *) printf 'Unknown option: %s\nUse --help for instructions.\n' "$1"; exit 2 ;;
esac
if [[ $# -gt 1 && -z "$install_target" ]]; then
  printf 'Use --help for instructions.\n'
  exit 2
fi

brew_bin="$(command -v brew 2>/dev/null || true)"
if [[ ! -x "$brew_bin" ]]; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      brew_bin="$candidate"
      break
    fi
  done
fi
if [[ ! -x "$brew_bin" ]]; then
  printf 'Homebrew was not found. Install it from https://brew.sh, then run this updater again.\n'
  exit 1
fi
export PATH="$(dirname "$brew_bin"):/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# Refresh once, and limit installation/upgrade work to the named apps.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_NO_ASK=1

tap='leapps-org/leapps'
targets=(
  'LAVA|lava'
  'ALEAPP|aleapp-gui'
  'iLEAPP|ileapp-gui'
  'RLEAPP|rleapp-gui'
  'VLEAPP|vleapp-gui'
  'DLEAPP|dleapp-gui'
  'GLEAPP|gleapp'
)

run() {
  if [[ "$preview" -eq 1 ]]; then
    printf 'Would run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

event() {
  if [[ "${ULEAPP_EVENTS:-0}" == 1 && "$preview" -eq 0 ]]; then
    printf 'ULEAPP\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
  fi
}
check_stop() {
  if [[ -n "${ULEAPP_CANCEL_FILE:-}" && -f "$ULEAPP_CANCEL_FILE" ]]; then
    printf '\nStopped at your request. Completed work has been kept.\n'
    event phase '' stopped 'Stopped after the current operation.'
    exit 130
  fi
}
report_version() {
  local version_lines token version
  installed_version=''
  if version_lines="$("$brew_bin" list --cask --versions "$cask")"; then
    while read -r token version; do
      if [[ "${token##*/}" == "$cask" && -n "$version" ]]; then
        installed_version="$version"
        event version "$cask" '' "$version"
        break
      fi
    done <<< "$version_lines"
  fi
}
confirm_current() {
  if [[ "$preview" -eq 1 ]]; then return 0; fi
  local checker latest_version check_status
  checker="${ULEAPP_RELEASE_CHECKER:-}"
  if [[ -z "$checker" ]]; then
    checker="$(cd "$(dirname "$0")/.." && pwd)/MacOS/uLEAPP"
    if [[ ! -x "$checker" ]]; then
      checker="$(cd "$(dirname "$0")/.." && pwd)/uLEAPP.app/Contents/MacOS/uLEAPP"
    fi
  fi
  if [[ ! -x "$checker" ]]; then
    printf 'Cannot verify the GitHub release. Run this worker from the complete uLEAPP app.\n'
    return 1
  fi
  latest_version="$("$checker" --check-tool-release "$cask" "$installed_version")"
  check_status=$?
  case "$check_status" in
    0) event app "$cask" current 'Up to date'; return 0 ;;
    10)
      pending_count=$((pending_count + 1))
      event upstream "$cask" '' "$latest_version"
      event app "$cask" pending 'Homebrew update pending'
      printf '%s: GitHub release %s is newer than installed %s. Homebrew has not installed the latest release. Official download: https://github.com/%s/releases/latest\n' "$name" "$latest_version" "$installed_version" "$repository"
      return 0 ;;
    *) printf '%s: could not verify the latest GitHub release. Update status is unknown.\n' "$name"; return 1 ;;
  esac
}

printf '\nLEAPP Updater\n=============\n'
if [[ "$preview" -eq 1 ]]; then
  printf 'Preview only. No changes will be made.\n'
else
  if [[ "$check_only" -eq 1 ]]; then
    printf 'Checking your installed LEAPP apps for updates.\n'
  elif [[ "$install_missing" -eq 1 || -n "$install_target" ]]; then
    printf 'Installing the requested missing LEAPP apps.\n'
    printf 'LAVA is freeware under separate terms: https://github.com/leapps-org/LAVA-releases/blob/main/LICENSE\n'
  else
    printf 'Updating your installed LEAPP apps. Please keep these apps closed.\n'
  fi
fi

printf '\nPreparing the official LEAPP Homebrew tap...\n'
event phase '' preparing 'Preparing Homebrew'
check_stop
trust_supported=0
if "$brew_bin" help trust >/dev/null 2>&1; then
  trust_supported=1
  if ! run "$brew_bin" trust "$tap"; then
    printf 'Could not trust the LEAPP tap. No apps were updated.\n'
    exit 1
  fi
fi
if ! run "$brew_bin" tap "$tap"; then
  printf 'Could not prepare the LEAPP tap. No apps were updated.\n'
  exit 1
fi
check_stop
event phase '' refreshing 'Refreshing Homebrew'
if ! run "$brew_bin" update; then
  printf 'Could not refresh Homebrew. Check your connection and try again.\n'
  exit 1
fi
check_stop
# Homebrew may gain the trust command during its own update.
if [[ "$trust_supported" -eq 0 ]] && "$brew_bin" help trust >/dev/null 2>&1; then
  if ! run "$brew_bin" trust "$tap"; then
    printf 'Could not trust the LEAPP tap after updating Homebrew.\n'
    exit 1
  fi
fi

if ! installed_casks="$("$brew_bin" list --cask -1)"; then
  printf 'Could not read the installed Homebrew apps.\n'
  exit 1
fi
is_managed() {
  local installed
  while IFS= read -r installed; do
    if [[ "${installed##*/}" == "$1" ]]; then
      return 0
    fi
  done <<< "$installed_casks"
  return 1
}

success_count=0
available_count=0
pending_count=0
failed_count=0
skipped_count=0
failed_apps=''
for target in "${targets[@]}"; do
  check_stop
  IFS='|' read -r name cask <<< "$target"
  if [[ -n "$install_target" && "$install_target" != "$cask" ]]; then
    continue
  fi
  printf '\n--- %s ---\n' "$name"
  if [[ "$cask" == lava ]]; then repository='leapps-org/LAVA-releases'; else repository="abrignoni/$name"; fi
  result=0
  if is_managed "$cask"; then
    report_version
    if [[ "$install_missing" -eq 1 || -n "$install_target" ]]; then
      printf '%s is already installed.\n' "$name"
      event app "$cask" installed 'Already installed'
      success_count=$((success_count + 1))
      continue
    fi
    if [[ "$check_only" -eq 1 ]]; then
      event app "$cask" checking 'Checking for updates'
      # A named outdated cask exits 1 by design. Keep stderr in the log and
      # require an exact quiet-output token before treating that as an update.
      outdated_output="$("$brew_bin" outdated --cask --greedy --quiet "$tap/$cask")"
      outdated_status=$?
      if [[ "$outdated_status" -le 1 && ( "$outdated_output" == "$cask" || "$outdated_output" == "$tap/$cask" ) ]]; then
        available_count=$((available_count + 1))
        event app "$cask" available 'Update available'
        printf '%s: update available.\n' "$name"
      elif [[ "$outdated_status" -eq 0 && -z "$outdated_output" ]]; then
        confirm_current || result=$?
      else
        result=1
        if [[ -n "$outdated_output" ]]; then
          printf 'Unexpected Homebrew check response: %s\n' "$outdated_output"
        fi
      fi
    else
      event app "$cask" updating 'Updating'
      run "$brew_bin" upgrade --cask --greedy "$tap/$cask" || result=$?
      if [[ "$result" -eq 0 ]]; then
        report_version
        confirm_current || result=$?
      fi
    fi
  else
    if [[ "$install_missing" -eq 1 || -n "$install_target" ]]; then
      event app "$cask" installing 'Installing'
      # --adopt also handles a matching manually installed app without forcing
      # replacement. A different existing app is left intact and reported.
      run "$brew_bin" install --cask --adopt "$tap/$cask" || result=$?
      if [[ "$result" -eq 0 ]]; then
        report_version
        confirm_current || result=$?
      fi
    else
      printf 'Not managed by Homebrew; skipping.\n'
      event app "$cask" skipped 'Not managed by Homebrew'
      skipped_count=$((skipped_count + 1))
      continue
    fi
  fi

  if [[ "$result" -eq 0 ]]; then
    success_count=$((success_count + 1))
    if [[ "$preview" -eq 0 && "$check_only" -eq 0 ]]; then
      printf '%s: ready.\n' "$name"
    fi
  else
    event app "$cask" failed 'See details for the Homebrew error'
    printf '%s could not be updated. See the Homebrew error above.\n' "$name"
    failed_count=$((failed_count + 1))
    failed_apps="$failed_apps $name"
  fi
done

check_stop
if [[ "$pending_count" -gt 0 ]]; then printf '%s new releases await Homebrew. Use the official download links above.\n' "$pending_count"; fi
printf '\n=============\n'
if [[ "$preview" -eq 1 ]]; then
  printf 'Preview finished: %s apps managed by Homebrew; %s skipped.\n' "$success_count" "$skipped_count"
elif [[ "$check_only" -eq 1 ]]; then
  printf 'Checked: %s apps; %s updates available; %s failed; %s skipped.\n' "$success_count" "$available_count" "$failed_count" "$skipped_count"
else
  printf 'Finished: %s apps ready; %s failed; %s skipped.\n' "$success_count" "$failed_count" "$skipped_count"
fi
if [[ "$failed_count" -gt 0 ]]; then
  printf 'Needs attention:%s\nFix the errors above and run this updater again.\n' "$failed_apps"
  exit 1
fi
exit 0
