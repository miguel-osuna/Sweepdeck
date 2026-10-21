#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/sweepdeck-plist-test.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT

plist_path="$fixture_dir/Info.plist"
cp Resources/Info.plist "$plist_path"
bash scripts/set-app-version.sh "$plist_path" 0.1.0
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
[[ "$actual_version" == "0.1.0" ]]

if bash scripts/set-app-version.sh "$plist_path" "1.2.3; touch $fixture_dir/injected" >/dev/null 2>&1; then
  echo "Unsafe release version was accepted." >&2
  exit 1
fi
[[ ! -e "$fixture_dir/injected" ]]
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
[[ "$actual_version" == "0.1.0" ]]

echo "App bundle version tests passed."
