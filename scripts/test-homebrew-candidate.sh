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
release_url="https://github.com/miguel-osuna/Sweepdeck/releases/download/v${version}/Sweepdeck-${version}-macOS.zip"

finish() {
  result=$?
  set +e
  osascript -e 'tell application "Sweepdeck" to quit' >/dev/null 2>&1
  launchctl unsetenv SWEEPDECK_STATE_DIR >/dev/null 2>&1
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
brew list --cask --versions "$cask_name"
[[ -d "$app_path/Contents/MacOS" && -f "$app_path/Contents/Info.plist" ]]
installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
[[ "$installed_version" == "$version" ]]
file "$app_path/Contents/MacOS/Sweepdeck"
find "$app_path" -maxdepth 4 -print

quarantine="$(xattr -p com.apple.quarantine "$app_path")"
printf 'Homebrew quarantine: %s\n' "$quarantine"
launchctl setenv SWEEPDECK_STATE_DIR "$temporary_state"

set +e
spctl --assess --type execute --verbose=4 "$app_path" >"$temporary_dir/gatekeeper.txt" 2>&1
gatekeeper_status=$?
open -a "$app_path" >"$temporary_dir/first-launch.txt" 2>&1
open_status=$?
sleep 5
if pgrep -x Sweepdeck >/dev/null 2>&1; then
  launch_status=0
else
  launch_status=1
fi
set -e

cat "$temporary_dir/gatekeeper.txt"
cat "$temporary_dir/first-launch.txt"
if [[ "$gatekeeper_status" -ne 0 || "$open_status" -ne 0 || "$launch_status" -ne 0 ]]; then
  echo "The Homebrew-quarantined release candidate did not pass Gatekeeper and first-launch checks." >&2
  exit 1
fi

osascript -e 'tell application "Sweepdeck" to quit'
brew uninstall --cask "$cask_name"
[[ ! -e "$app_path" ]]
echo "Homebrew candidate install, quarantine, first launch, and uninstall checks passed."
