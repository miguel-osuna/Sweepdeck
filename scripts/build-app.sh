#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/swift.sh build -c release
binary_dir="$(bash scripts/swift.sh build -c release --show-bin-path)"
stage="/private/tmp/SweepdeckBuild-stage"
bundle="$stage/Sweepdeck.app"
archive="$PWD/dist/Sweepdeck-macOS.zip"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources" "$PWD/dist"
cp "$binary_dir/Sweepdeck" "$bundle/Contents/MacOS/Sweepdeck"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
# Sign from local temporary storage; the Documents folder provider reattaches
# Finder metadata to .app directories and macOS rejects those bytes for signing.
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
ditto -c -k --keepParent --norsrc --noextattr --noqtn "$bundle" "$archive.tmp"
mv -f "$archive.tmp" "$archive"
rm -rf "$PWD/dist/Sweepdeck.app"
echo "Built and verified $archive"
