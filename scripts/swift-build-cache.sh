#!/usr/bin/env bash
set -euo pipefail

prepare_swift_build_cache() {
    local build_dir="$1"
    local workspace_path="$2"
    local marker="$build_dir/.sweepdeck-workspace-path"
    local previous_path=""
    local arch_dir
    local has_arch_cache=false
    local should_clear=false

    if [[ -f "$marker" ]]; then
        IFS= read -r previous_path < "$marker" || true
    fi

    if [[ -n "$previous_path" ]]; then
        if [[ "$previous_path" != "$workspace_path" ]]; then
            should_clear=true
        fi
    else
        for arch_dir in "$build_dir"/*-apple-macosx; do
            if [[ -d "$arch_dir" ]]; then
                has_arch_cache=true
                break
            fi
        done
        if [[ "$has_arch_cache" == true || -d "$build_dir/clang-cache" ]]; then
            should_clear=true
        fi
    fi

    if [[ "$should_clear" == true ]]; then
        if [[ -L "$build_dir" ]]; then
            echo "Refusing to clear relocated Swift caches through a symlinked .build directory." >&2
            return 1
        fi
        echo "Clearing Swift build caches created at a different or unrecorded workspace path." >&2
        for arch_dir in "$build_dir"/*-apple-macosx; do
            if [[ -e "$arch_dir" ]]; then
                rm -rf -- "$arch_dir"
            fi
        done
        rm -rf -- "$build_dir/clang-cache"
    fi

    mkdir -p "$build_dir"
    printf '%s\n' "$workspace_path" > "$marker.tmp.$$"
    mv -f -- "$marker.tmp.$$" "$marker"
}
