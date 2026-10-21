#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
dmg="${2:-}"
bash "$(dirname "$0")/validate-release-version.sh" "$version"
[[ -f "$dmg" && -f "$dmg.sha256" ]] || {
  echo "The versioned DMG and checksum are required." >&2
  exit 66
}

dmg="$(cd "$(dirname "$dmg")" && pwd)/$(basename "$dmg")"
(cd "$(dirname "$dmg")" && shasum -a 256 --check "$(basename "$dmg").sha256")
[[ "${GITHUB_ACTIONS:-}" == "true" && "${SWEEPDECK_DISPOSABLE_RUNNER:-}" == "true" ]] || {
  echo "This DMG check mounts a disk image; run it only on the disposable GitHub-hosted Apple Silicon runner." >&2
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
  echo "DMG candidate checks require an Apple Silicon runner." >&2
  exit 1
}

temporary_dir="$(mktemp -d "$RUNNER_TEMP/sweepdeck-dmg.${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}.XXXXXX")"
mount_point="$temporary_dir/mount"
mkdir -p "$mount_point"
mounted=0

cleanup() {
  result=$?
  trap - EXIT
  set +e
  if [[ "$mounted" -eq 1 ]]; then
    hdiutil detach "$mount_point" >/dev/null 2>&1
  fi
  rm -rf "$temporary_dir"
  exit "$result"
}
trap cleanup EXIT

hdiutil verify "$dmg"
hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" "$dmg"
mounted=1
app="$mount_point/Sweepdeck.app"
[[ -d "$app/Contents/MacOS" && -f "$app/Contents/Info.plist" ]] || {
  echo "The DMG does not contain the expected Sweepdeck.app bundle." >&2
  exit 65
}
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$app_version" == "$version" ]] || {
  echo "Expected app version $version; the DMG bundle reports $app_version." >&2
  exit 65
}
[[ -f "$app/Contents/Resources/Sweepdeck.icns" ]] || {
  echo "The app icon is missing from the DMG bundle." >&2
  exit 65
}
[[ -L "$mount_point/Applications" && "$(readlink "$mount_point/Applications")" == "/Applications" ]] || {
  echo "The DMG is missing its Applications shortcut." >&2
  exit 65
}
[[ -f "$mount_point/INSTALL.txt" ]] || {
  echo "The DMG is missing its installation and Gatekeeper instructions." >&2
  exit 65
}
grep -Fq "Open Anyway" "$mount_point/INSTALL.txt"
grep -Fq "does not turn off Gatekeeper" "$mount_point/INSTALL.txt"
codesign --verify --strict "$app"
find "$mount_point" -maxdepth 2 -print
hdiutil detach "$mount_point"
mounted=0
echo "DMG checksum, image, app bundle, icon, Applications shortcut, and install instructions passed inspection."
echo "This check did not download the DMG, simulate Gatekeeper quarantine, or approve the app."
