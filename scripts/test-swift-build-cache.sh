#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
helper="$script_dir/swift-build-cache.sh"
if [[ ! -f "$helper" ]]; then
    echo "Swift build cache relocation policy is missing." >&2
    exit 1
fi

# shellcheck source=scripts/swift-build-cache.sh
source "$helper"

fixture="$(mktemp -d "${TMPDIR:-/tmp}/sweepdeck-swift-cache.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT

assert_present() {
    if [[ ! -e "$1" ]]; then
        echo "Expected path to remain: $1" >&2
        exit 1
    fi
}

assert_absent() {
    if [[ -e "$1" ]]; then
        echo "Expected path to be removed: $1" >&2
        exit 1
    fi
}

# A checkout moved to a new absolute path must discard SwiftPM and Clang caches
# while keeping the workspace-local Rust installation and target directory.
moved_build="$fixture/moved checkout/.build"
mkdir -p "$moved_build/arm64-apple-macosx/debug/ModuleCache" \
    "$moved_build/clang-cache" "$moved_build/rustup/toolchains" "$moved_build/rust/debug"
printf '%s\n' "$fixture/previous checkout" > "$moved_build/.sweepdeck-workspace-path"
touch "$moved_build/arm64-apple-macosx/debug/ModuleCache/stale.pcm" \
    "$moved_build/clang-cache/stale.pcm" \
    "$moved_build/rustup/toolchains/rustc" \
    "$moved_build/rust/debug/libaccelerator.a"

prepare_swift_build_cache "$moved_build" "$fixture/moved checkout"
assert_absent "$moved_build/arm64-apple-macosx"
assert_absent "$moved_build/clang-cache"
assert_present "$moved_build/rustup/toolchains/rustc"
assert_present "$moved_build/rust/debug/libaccelerator.a"
[[ "$(<"$moved_build/.sweepdeck-workspace-path")" == "$fixture/moved checkout" ]]

# A cache already associated with the current checkout remains reusable.
stable_build="$fixture/stable checkout/.build"
mkdir -p "$stable_build/arm64-apple-macosx/debug/ModuleCache"
printf '%s\n' "$fixture/stable checkout" > "$stable_build/.sweepdeck-workspace-path"
touch "$stable_build/arm64-apple-macosx/debug/ModuleCache/current.pcm"
prepare_swift_build_cache "$stable_build" "$fixture/stable checkout"
assert_present "$stable_build/arm64-apple-macosx/debug/ModuleCache/current.pcm"

# Existing pre-marker caches are treated as relocatable legacy state once.
legacy_build="$fixture/legacy checkout/.build"
mkdir -p "$legacy_build/x86_64-apple-macosx/debug/ModuleCache"
touch "$legacy_build/x86_64-apple-macosx/debug/ModuleCache/legacy.pcm"
prepare_swift_build_cache "$legacy_build" "$fixture/legacy checkout"
assert_absent "$legacy_build/x86_64-apple-macosx"
[[ "$(<"$legacy_build/.sweepdeck-workspace-path")" == "$fixture/legacy checkout" ]]

# A truncated marker must be treated like unrecorded legacy state.
empty_marker_build="$fixture/empty marker checkout/.build"
mkdir -p "$empty_marker_build/arm64-apple-macosx/debug/ModuleCache"
: > "$empty_marker_build/.sweepdeck-workspace-path"
touch "$empty_marker_build/arm64-apple-macosx/debug/ModuleCache/legacy.pcm"
prepare_swift_build_cache "$empty_marker_build" "$fixture/empty marker checkout"
assert_absent "$empty_marker_build/arm64-apple-macosx"

# A symlinked .build directory must never make cache cleanup reach outside the
# checkout.
external_build="$fixture/external build"
mkdir -p "$external_build/arm64-apple-macosx/debug/ModuleCache" \
    "$fixture/linked checkout"
printf '%s\n' "$fixture/previous checkout" > "$external_build/.sweepdeck-workspace-path"
touch "$external_build/arm64-apple-macosx/debug/ModuleCache/must-survive.pcm"
ln -s "$external_build" "$fixture/linked checkout/.build"
if prepare_swift_build_cache "$fixture/linked checkout/.build" "$fixture/linked checkout" 2>/dev/null; then
    echo "Expected cache preparation to refuse a moved symlinked .build directory." >&2
    exit 1
fi
assert_present "$external_build/arm64-apple-macosx/debug/ModuleCache/must-survive.pcm"

echo "Swift build cache relocation checks passed."
