#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="2.10.0"
expected_sha256="17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959"
base="$PWD/.build/dependencies/sparkle"
archive="$PWD/.build/dependencies/downloads/Sparkle-for-Swift-Package-Manager.zip"
url="https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-for-Swift-Package-Manager.zip"

mkdir -p "$(dirname "$archive")" "$base"
if [[ ! -f "$archive" ]] || [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" != "$expected_sha256" ]]; then
  rm -f "$archive"
  curl --fail --location --silent --show-error "$url" --output "$archive.tmp"
  actual_sha256="$(shasum -a 256 "$archive.tmp" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -f "$archive.tmp"
    echo "Sparkle $version archive checksum mismatch." >&2
    exit 65
  fi
  mv -f "$archive.tmp" "$archive"
fi

framework="$base/Sparkle.xcframework"
if [[ ! -d "$framework" ]]; then
  temporary_directory="$(mktemp -d "$base/.extract.XXXXXX")"
  trap 'rm -rf "$temporary_directory"' EXIT
  unzip -q "$archive" -d "$temporary_directory"
  [[ -d "$temporary_directory/Sparkle.xcframework" ]] || {
    echo "Sparkle $version archive did not contain Sparkle.xcframework." >&2
    exit 65
  }
  ditto "$temporary_directory/Sparkle.xcframework" "$framework"
  ditto "$temporary_directory/bin" "$base/bin"
  cp "$temporary_directory/LICENSE" "$base/LICENSE"
  trap - EXIT
  rm -rf "$temporary_directory"
fi

codesign --verify --strict --deep "$framework/macos-arm64_x86_64/Sparkle.framework"
echo "Prepared verified Sparkle $version in .build/dependencies/sparkle." >&2
