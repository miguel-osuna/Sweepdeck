#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
archive="${2:-}"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "Expected a stable three-part version; received: $version" >&2
  exit 64
}
[[ -f "$archive" && -f "$archive.sha256" ]] || {
  echo "The versioned archive and checksum are required." >&2
  exit 66
}

archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
expected_sha="$(awk '{print $1}' "$archive.sha256")"
actual_sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
[[ "$expected_sha" == "$actual_sha" ]] || {
  echo "The candidate archive does not match its recorded SHA-256." >&2
  exit 65
}
[[ "${GITHUB_ACTIONS:-}" == "true" && "${SWEEPDECK_DISPOSABLE_RUNNER:-}" == "true" ]] || {
  echo "This check installs and uninstalls a cask; run it only on the disposable GitHub-hosted Apple Silicon runner." >&2
  exit 1
}
[[ -n "${RUNNER_TEMP:-}" && -d "$RUNNER_TEMP" && -w "$RUNNER_TEMP" ]] || {
  echo "A writable GitHub Actions RUNNER_TEMP directory is required." >&2
  exit 1
}
[[ "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ && "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]] || {
  echo "A GitHub Actions run ID and attempt are required to isolate test artifacts." >&2
  exit 1
}
[[ "$(uname -m)" == "arm64" ]] || {
  echo "Release quarantine checks require an Apple Silicon runner." >&2
  exit 1
}
app_path="/Applications/Sweepdeck.app"
tap_name="miguel-osuna/tap"
cask_name="$tap_name/sweepdeck"
if [[ -e "$app_path" ]] || brew list --cask --full-name 2>/dev/null | grep -Fxq "$cask_name"; then
  echo "The disposable runner already has Sweepdeck installed; refusing to change its existing state." >&2
  exit 1
fi
if brew tap | grep -Fxq "$tap_name"; then
  echo "The disposable runner already has $tap_name tapped; refusing to change its existing state." >&2
  exit 1
fi

brew update
export HOMEBREW_NO_AUTO_UPDATE=1

temporary_dir="$(mktemp -d "$RUNNER_TEMP/sweepdeck-homebrew.${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}.XXXXXX")"
tap_dir="$temporary_dir/homebrew-tap"
cask_path="$tap_dir/Casks/sweepdeck.rb"
temporary_state="$temporary_dir/state"
first_launch_screenshot_prefix="$RUNNER_TEMP/Sweepdeck-first-launch-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
release_url='https://github.com/miguel-osuna/Sweepdeck/releases/download/v#{version}/Sweepdeck-#{version}-macOS.zip'
open_pid=""
tap_created=0
install_started=0

test_app_pids() {
  local pid process_command
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    process_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$process_command" == *"--sweepdeck-state-directory"* && "$process_command" == *"$temporary_state"* ]]; then
      printf '%s\n' "$pid"
    fi
  done < <(pgrep -x Sweepdeck 2>/dev/null || true)
}

stop_test_app() {
  local pid
  if [[ -n "$open_pid" ]]; then
    kill -TERM "$open_pid" >/dev/null 2>&1 || true
  fi
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill -TERM "$pid" >/dev/null 2>&1 || true
  done < <(test_app_pids)
}

finish() {
  result=$?
  set +e
  stop_test_app
  if [[ "$install_started" -eq 1 ]] && brew list --cask --full-name 2>/dev/null | grep -Fxq "$cask_name"; then
    brew uninstall --cask "$cask_name"
  fi
  if [[ "$install_started" -eq 1 && -e "$app_path" ]]; then
    echo "Homebrew uninstall left $app_path behind on the disposable runner." >&2
    result=1
  fi
  if [[ "$tap_created" -eq 1 ]]; then
    brew untap --force "$tap_name"
  fi
  rm -rf "$temporary_dir"
  exit "$result"
}
trap finish EXIT

capture_first_launch_screenshot() {
  local stage="$1"
  local screenshot="${first_launch_screenshot_prefix}-${stage}.png"
  if screencapture -x "$screenshot" >/dev/null 2>&1 && [[ -s "$screenshot" ]]; then
    echo "Captured the disposable runner's $stage first-launch screen: $screenshot"
  else
    echo "The disposable runner did not provide a capturable $stage screen."
  fi
}

mkdir -p "$(dirname "$cask_path")" "$temporary_state"
cat > "$cask_path" <<EOF
cask "sweepdeck" do
  version "$version"
  sha256 "$expected_sha"

  url "$release_url"
  name "Sweepdeck"
  desc "Review local files before moving them to Trash"
  homepage "https://github.com/miguel-osuna/Sweepdeck"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Sweepdeck.app"

  caveats <<~EOS
    This ad-hoc signed build has no Apple-issued Developer ID signature or
    notarization ticket, so macOS may block its first launch. Continue only if you
    trust that you installed Sweepdeck from this tap or its official GitHub release.

    To approve Sweepdeck once:
      1. Click Done in the warning. Move to Trash removes the app.
      2. Open System Settings > Privacy & Security, scroll to Security, and click
         Open Anyway for Sweepdeck.
      3. When the warning appears again, click Open if you still want to run it.

    macOS saves this as a per-app exception for future launches. Homebrew leaves
    quarantine in place, and this cask does not bypass Gatekeeper.
  EOS
end
EOF

git -C "$tap_dir" init --quiet --initial-branch=main
git -C "$tap_dir" config user.name "Sweepdeck Release Validation"
git -C "$tap_dir" config user.email "sweepdeck-release-validation@users.noreply.github.com"
git -C "$tap_dir" add Casks/sweepdeck.rb
git -C "$tap_dir" commit --quiet -m "Add Sweepdeck release candidate cask"
brew tap "$tap_name" "$tap_dir"
tap_created=1
brew audit --cask --strict "$cask_name"
brew style --cask "$cask_name"

# Point only the disposable runner's local tap at the candidate bytes. The cask
# metadata audited above retains the stable versioned GitHub Release URL.
installed_tap="$(brew --repository "$tap_name")"
ruby - "$installed_tap/Casks/sweepdeck.rb" "$release_url" "file://$archive" <<'RUBY'
path, original_url, candidate_url = ARGV
contents = File.read(path)
abort "Expected release URL was not found in the cask" unless contents.include?(original_url)
File.write(path, contents.sub(original_url, candidate_url))
RUBY

[[ ! -e "$app_path" ]] || {
  echo "$app_path already exists on the disposable runner." >&2
  exit 1
}
install_started=1
brew install --cask "$cask_name"
brew info --cask "$cask_name"
brew list --cask --full-name | grep -Fx "$cask_name"
[[ -d "$app_path/Contents/MacOS" && -f "$app_path/Contents/Info.plist" ]] || {
  echo "Homebrew installed the cask but the expected app bundle is incomplete." >&2
  exit 1
}
installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
[[ "$installed_version" == "$version" ]] || {
  echo "Expected app version $version; installed bundle reports $installed_version." >&2
  exit 1
}
file "$app_path/Contents/MacOS/Sweepdeck"
find "$app_path" -maxdepth 4 -print

quarantine="$(xattr -p com.apple.quarantine "$app_path")"
printf 'Homebrew quarantine: %s\n' "$quarantine"
codesign --verify --strict "$app_path"
signature_info="$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)"
printf '%s\n' "$signature_info"
grep -Fq 'Signature=adhoc' <<<"$signature_info" || {
  echo "Expected the current no-cost build to use an ad-hoc signature." >&2
  exit 1
}
set +e
spctl --assess --type execute --verbose=4 "$app_path" >"$temporary_dir/gatekeeper.txt" 2>&1
gatekeeper_status=$?
cat "$temporary_dir/gatekeeper.txt"
open -a "$app_path" --args --sweepdeck-state-directory "$temporary_state" >"$temporary_dir/first-launch.txt" 2>&1 &
open_pid=$!
launch_started="$SECONDS"
open_status=0
early_screenshot_captured=0
for _ in {1..15}; do
  if [[ "$early_screenshot_captured" -eq 0 && "$((SECONDS - launch_started))" -ge 3 ]]; then
    capture_first_launch_screenshot early
    early_screenshot_captured=1
  fi
  if ! kill -0 "$open_pid" >/dev/null 2>&1; then
    wait "$open_pid"
    open_status=$?
    open_pid=""
    break
  fi
  sleep 1
done
if [[ -n "$open_pid" ]]; then
  echo "Launch Services did not return within 15 seconds." >>"$temporary_dir/first-launch.txt"
  kill -TERM "$open_pid" >/dev/null 2>&1 || true
  wait "$open_pid" >/dev/null 2>&1 || true
  open_status=124
  open_pid=""
fi
sleep 5
if [[ -n "$(test_app_pids)" ]]; then
  launch_status=0
  process_id="$(test_app_pids | head -n 1)"
  process_command="$(ps -p "$process_id" -o command=)"
  printf 'Sweepdeck process: %s\n' "$process_command"
  [[ "$process_command" == *"--sweepdeck-state-directory"* && "$process_command" == *"$temporary_state"* ]] || {
    echo "Sweepdeck did not receive the temporary state directory argument." >&2
    exit 1
  }
else
  launch_status=1
fi
capture_first_launch_screenshot final
set -e

cat "$temporary_dir/gatekeeper.txt"
cat "$temporary_dir/first-launch.txt"
printf 'Gatekeeper status: %s; Launch Services status: %s; app process: %s\n' \
  "$gatekeeper_status" "$open_status" "$launch_status"
if [[ "$gatekeeper_status" -eq 0 ]]; then
  [[ "$launch_status" -eq 0 ]] || {
    echo "Gatekeeper accepted the app, but the app process did not start." >&2
    exit 1
  }
  echo "Gatekeeper accepted the quarantined app and its process started."
elif [[ "$gatekeeper_status" -eq 3 ]]; then
  echo "Gatekeeper rejected the ad-hoc signed app for unattended launch."
  echo "The app may require an explicit user decision in System Settings > Privacy & Security."
  echo "This check did not simulate user approval or remove quarantine."
else
  echo "Unexpected Gatekeeper assessment status: $gatekeeper_status" >&2
  exit 1
fi

if [[ "$launch_status" -eq 0 ]]; then
  stop_test_app
  for _ in {1..10}; do
    [[ -z "$(test_app_pids)" ]] || { sleep 1; continue; }
    break
  done
  if [[ -n "$(test_app_pids)" ]]; then
    echo "Sweepdeck did not stop after the first-launch check." >&2
    exit 1
  fi
fi
brew uninstall --cask "$cask_name"
install_started=0
[[ ! -e "$app_path" ]]
echo "Homebrew candidate audit, style, install, quarantine, Gatekeeper report, and uninstall checks completed."
