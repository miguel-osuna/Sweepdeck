#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -n "${SWEEPDECK_VERSION:-}" ]]; then
  bash scripts/validate-release-version.sh "$SWEEPDECK_VERSION"
fi

bash scripts/swift.sh build -c release
binary_dir="$(bash scripts/swift.sh build -c release --show-bin-path)"
stage="${SWEEPDECK_BUILD_STAGE:-/private/tmp/SweepdeckBuild-stage}"
bundle="$stage/Sweepdeck.app"
archive="${SWEEPDECK_ARCHIVE_PATH:-$PWD/dist/Sweepdeck-macOS.zip}"
if [[ -n "${SWEEPDECK_VERSION:-}" && -z "${SWEEPDECK_ARCHIVE_PATH:-}" ]]; then
  archive="$PWD/dist/Sweepdeck-${SWEEPDECK_VERSION}-macOS.zip"
fi
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$PWD/dist" "$(dirname "$archive")"
cp "$binary_dir/Sweepdeck" "$bundle/Contents/MacOS/Sweepdeck"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
if [[ -n "${SWEEPDECK_VERSION:-}" ]]; then
  bash scripts/set-app-version.sh "$bundle/Contents/Info.plist" "$SWEEPDECK_VERSION"
fi
# Drop the local symbol table from the distributable. Keep the unstripped build
# product under .build for debugging and coverage tools.
strip -S -x "$bundle/Contents/MacOS/Sweepdeck"
# Sign from local temporary storage; the Documents folder provider reattaches
# Finder metadata to .app directories and macOS rejects those bytes for signing.
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
ditto -c -k --keepParent --norsrc --noextattr --noqtn "$bundle" "$archive.tmp"
mv -f "$archive.tmp" "$archive"
(cd "$(dirname "$archive")" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
rm -rf "$PWD/dist/Sweepdeck.app"
ln -s "$bundle" "$PWD/dist/Sweepdeck.app"
codesign --verify --strict "$PWD/dist/Sweepdeck.app"
echo "Built and verified $archive"
cat "$archive.sha256"
