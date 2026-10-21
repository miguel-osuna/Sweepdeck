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
[[ "$(uname -m)" == "arm64" ]] || {
  echo "Release quarantine checks require an Apple Silicon runner." >&2
  exit 1
}
brew update
export HOMEBREW_NO_AUTO_UPDATE=1

temporary_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/sweepdeck-homebrew.XXXXXX")"
tap_dir="$temporary_dir/homebrew-tap"
cask_path="$tap_dir/Casks/sweepdeck.rb"
temporary_state="$temporary_dir/state"
app_path="/Applications/Sweepdeck.app"
tap_name="miguel-osuna/tap"
cask_name="$tap_name/sweepdeck"
first_launch_screenshot_dir="${RUNNER_TEMP:-/tmp}"
release_url='https://github.com/miguel-osuna/Sweepdeck/releases/download/v#{version}/Sweepdeck-#{version}-macOS.zip'
open_pid=""

stop_test_app() {
  if [[ -n "$open_pid" ]]; then
    kill -TERM "$open_pid" >/dev/null 2>&1 || true
  fi
  pkill -TERM -x Sweepdeck >/dev/null 2>&1 || true
}

finish() {
  result=$?
  set +e
  stop_test_app
  if brew list --cask --full-name 2>/dev/null | grep -Fxq "$cask_name"; then
    brew uninstall --cask "$cask_name"
  fi
  if [[ -e "$app_path" ]]; then
    echo "Homebrew uninstall left $app_path behind on the disposable runner." >&2
    result=1
  fi
  rm -rf "$temporary_dir"
  exit "$result"
}
trap finish EXIT

capture_first_launch_screenshot() {
  local stage="$1"
  local screenshot="$first_launch_screenshot_dir/Sweepdeck-first-launch-$stage.png"
  if screencapture -x "$screenshot" >/dev/null 2>&1 && [[ -s "$screenshot" ]]; then
    echo "Captured the disposable runner's $stage first-launch screen: $screenshot"
  else
    rm -f "$screenshot"
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
    macOS may show a security warning the first time you open Sweepdeck. This build
    has an ad-hoc signature, no Apple-issued Developer ID signature, and no
    notarization ticket. If macOS blocks the app, you can choose whether to allow it
    in System Settings > Privacy & Security > Open Anyway. Homebrew leaves quarantine
    in place and the cask does not bypass Gatekeeper.
  EOS
end
EOF

git -C "$tap_dir" init --quiet --initial-branch=main
git -C "$tap_dir" config user.name "Sweepdeck Release Validation"
git -C "$tap_dir" config user.email "sweepdeck-release-validation@users.noreply.github.com"
git -C "$tap_dir" add Casks/sweepdeck.rb
git -C "$tap_dir" commit --quiet -m "Add Sweepdeck release candidate cask"
brew tap "$tap_name" "$tap_dir"
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
rm -f "$first_launch_screenshot_dir"/Sweepdeck-first-launch-*.png

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
if pgrep -x Sweepdeck >/dev/null 2>&1; then
  launch_status=0
  process_id="$(pgrep -x Sweepdeck | head -n 1)"
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
  pkill -TERM -x Sweepdeck
  for _ in {1..10}; do
    pgrep -x Sweepdeck >/dev/null 2>&1 || break
    sleep 1
  done
  if pgrep -x Sweepdeck >/dev/null 2>&1; then
    echo "Sweepdeck did not stop after the first-launch check." >&2
    exit 1
  fi
fi
brew uninstall --cask "$cask_name"
[[ ! -e "$app_path" ]]
echo "Homebrew candidate audit, style, install, quarantine, Gatekeeper report, and uninstall checks completed."
