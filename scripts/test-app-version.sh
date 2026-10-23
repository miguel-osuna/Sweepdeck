#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/sweepdeck-plist-test.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT

default_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
default_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
if [[ "$default_version" != "0.3.0" || "$default_build" != "0.3.0" ]]; then
  echo "Expected the local app metadata to match the latest release 0.3.0; received $default_version (build $default_build)." >&2
  exit 1
fi

plist_path="$fixture_dir/Info.plist"
cp Resources/Info.plist "$plist_path"
bash scripts/set-app-version.sh "$plist_path" 0.1.0
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
[[ "$actual_version" == "0.1.0" ]]
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist_path")"
if [[ "$actual_build" != "0.1.0" ]]; then
  echo "Expected CFBundleVersion 0.1.0; received $actual_build." >&2
  exit 1
fi

if bash scripts/set-app-version.sh "$plist_path" "1.2.3; touch $fixture_dir/injected" >/dev/null 2>&1; then
  echo "Unsafe release version was accepted." >&2
  exit 1
fi
[[ ! -e "$fixture_dir/injected" ]]
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
[[ "$actual_version" == "0.1.0" ]]
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist_path")"
if [[ "$actual_build" != "0.1.0" ]]; then
  echo "Unsafe version modified CFBundleVersion to $actual_build." >&2
  exit 1
fi

echo "App bundle version tests passed."
