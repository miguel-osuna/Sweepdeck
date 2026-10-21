#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
archive="${2:-}"
bash scripts/validate-release-version.sh "$version"
[[ -f "$archive" && -f "$archive.sha256" ]] || {
  echo "The versioned ZIP archive and checksum are required." >&2
  exit 66
}

archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
(cd "$(dirname "$archive")" && shasum -a 256 --check "$(basename "$archive").sha256")
command -v hdiutil >/dev/null || { echo "hdiutil is required to build a DMG." >&2; exit 69; }
command -v ditto >/dev/null || { echo "ditto is required to unpack the app archive." >&2; exit 69; }

output="$PWD/dist/Sweepdeck-${version}-macOS.dmg"
sidecar="$output.sha256"
mkdir -p "$PWD/dist"
temporary_dir="$(mktemp -d "$PWD/dist/.SweepdeckDMG.${version}.XXXXXX")"

cleanup() {
  result=$?
  trap - EXIT
  rm -rf "$temporary_dir"
  exit "$result"
}
trap cleanup EXIT

staging="$temporary_dir/image"
image="$temporary_dir/Sweepdeck-${version}-macOS.dmg"
sidecar_tmp="$temporary_dir/Sweepdeck-${version}-macOS.dmg.sha256"
mkdir -p "$staging"
ditto -x -k "$archive" "$staging"
app="$staging/Sweepdeck.app"
[[ -d "$app/Contents/MacOS" && -f "$app/Contents/Info.plist" ]] || {
  echo "The ZIP does not contain the expected Sweepdeck.app bundle." >&2
  exit 65
}
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
[[ "$app_version" == "$version" ]] || {
  echo "Expected app version $version; the bundle reports $app_version." >&2
  exit 65
}
codesign --verify --strict "$app"
ln -s /Applications "$staging/Applications"
cat > "$staging/INSTALL.txt" <<'EOF'
Installing Sweepdeck

1. Drag Sweepdeck.app to the Applications folder in this window.
2. Eject the Sweepdeck disk image, then open Sweepdeck from Applications.

First launch and macOS security

This free build is ad-hoc signed and is not notarized by Apple. macOS may show a
warning that Apple cannot verify the app is free of malware. Continue only if you
downloaded this disk image from the official Sweepdeck GitHub release and trust it.

If you choose to continue:
1. Click Done in the warning; Move to Trash removes the app.
2. Open System Settings > Privacy & Security, scroll to Security, and click
   Open Anyway for Sweepdeck.
3. When the warning appears again, click Open if you still want to run it.

macOS saves this as an exception for Sweepdeck. This does not turn off Gatekeeper
for other apps. See Apple's security guidance: https://support.apple.com/en-au/102445
EOF

hdiutil create -volname "Sweepdeck" -srcfolder "$staging" -ov -format UDZO "$image"
hdiutil verify "$image"
digest="$(shasum -a 256 "$image" | awk '{print $1}')"
printf '%s  %s\n' "$digest" "$(basename "$output")" > "$sidecar_tmp"
mv -f "$image" "$output"
mv -f "$sidecar_tmp" "$sidecar"
(cd "$PWD/dist" && shasum -a 256 --check "$(basename "$sidecar")")
echo "Built and verified $output"
cat "$sidecar"
