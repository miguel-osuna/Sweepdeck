#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <Info.plist> <version>" >&2
  exit 64
fi

plist_path="$1"
version="$2"
if [[ ! -f "$plist_path" ]]; then
  echo "Info.plist not found: $plist_path" >&2
  exit 66
fi

bash scripts/validate-release-version.sh "$version"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist_path"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
if [[ "$actual_version" != "$version" ]]; then
  echo "Could not set app version in $plist_path" >&2
  exit 1
fi
