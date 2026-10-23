#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo_root="$(pwd -P)"
script_dir="$(cd "$(dirname "$0")" && pwd -P)"
source "$script_dir/swift-build-cache.sh"
prepare_swift_build_cache "$repo_root/.build" "$repo_root"
mkdir -p .build/local-toolchain
export CLANG_MODULE_CACHE_PATH="$repo_root/.build/clang-cache"

# Some CLT upgrades leave incompatible private interfaces and duplicate module maps.
# Work around the detected files locally; never edit the installed toolchain.
toolchain_usr="$(dirname "$(dirname "$(xcrun --find swift)")")"
manifest_api="$toolchain_usr/lib/swift/pm/ManifestAPI"
arch_name="$(uname -m)"
public_interface="$manifest_api/PackageDescription.swiftmodule/$arch_name-apple-macos.swiftinterface"
private_interface="$manifest_api/PackageDescription.swiftmodule/$arch_name-apple-macos.private.swiftinterface"
if [[ -f "$private_interface" ]] && grep -q 'swiftLanguageModes' "$public_interface" && ! grep -q 'swiftLanguageModes' "$private_interface"; then
    local_api="$PWD/.build/local-toolchain/ManifestAPI"
    mkdir -p "$local_api/PackageDescription.swiftmodule"
    cp "$public_interface" "$local_api/PackageDescription.swiftmodule/"
    cp "$manifest_api/libPackageDescription.dylib" "$local_api/"
    export SWIFTPM_CUSTOM_LIBS_DIR="$PWD/.build/local-toolchain"
    echo "Using workspace-local SwiftPM interface workaround." >&2
fi

extra_flags=()
testing_support_flags=()
testing_flags=()
legacy_map="$toolchain_usr/include/swift/module.modulemap"
current_map="$toolchain_usr/include/swift/bridging.modulemap"
if [[ -f "$legacy_map" && -f "$current_map" ]] && grep -q 'module SwiftBridging' "$legacy_map" && grep -q 'module SwiftBridging' "$current_map"; then
    printf '// Duplicate module map excluded by local VFS overlay.\n' > .build/local-toolchain/empty.modulemap
    /usr/bin/python3 - "$legacy_map" "$PWD/.build/local-toolchain" <<'PY'
import json, sys
from pathlib import Path
directory = Path(sys.argv[2])
overlay = {"version": 0, "roots": [{"type": "file", "name": sys.argv[1], "external-contents": str(directory / "empty.modulemap")}]}
(directory / "overlay.json").write_text(json.dumps(overlay))
PY
    extra_flags=(-Xswiftc -vfsoverlay -Xswiftc "$PWD/.build/local-toolchain/overlay.json")
    echo "Using workspace-local duplicate-module workaround." >&2
fi

command_name="${1:-build}"
if [[ $# -gt 0 ]]; then shift; fi

if [[ "$command_name" == "build" || "$command_name" == "test" || "$command_name" == "package" ]]; then
    bash scripts/prepare-sparkle.sh
fi

if [[ "$command_name" == "test" || "$command_name" == "build" ]]; then
    toolchain_bin="$PWD/.build/rustup/toolchains/1.99.1-aarch64-apple-darwin/bin"
    local_rust_toolchain=false
    if [[ -x "$toolchain_bin/cargo" && -x "$toolchain_bin/rustc" ]]; then
        export CARGO_HOME="$PWD/.build/cargo"
        export RUSTUP_HOME="$PWD/.build/rustup"
        export PATH="$toolchain_bin:$PATH"
        export RUSTC="$toolchain_bin/rustc"
        export RUSTDOC="$toolchain_bin/rustdoc"
        cargo_command="$toolchain_bin/cargo"
        local_rust_toolchain=true
    elif command -v cargo >/dev/null 2>&1; then
        cargo_command="$(command -v cargo)"
    else
        echo "Rust 1.99.1 is required. Install rustup and the toolchain from rust-toolchain.toml." >&2
        exit 1
    fi

    export CARGO_TARGET_DIR="$PWD/.build/rust"
    if [[ "$local_rust_toolchain" == true ]]; then
        mkdir -p "$CARGO_TARGET_DIR/lint"
        "$toolchain_bin/rustfmt" --edition 2024 --check rust/sweepdeck-accelerator/src/lib.rs
        "$toolchain_bin/clippy-driver" --edition=2024 --crate-name sweepdeck_accelerator \
            --crate-type lib --deny warnings --emit=metadata \
            --out-dir "$CARGO_TARGET_DIR/lint" rust/sweepdeck-accelerator/src/lib.rs
        "$toolchain_bin/clippy-driver" --edition=2024 --crate-name sweepdeck_accelerator \
            --test --deny warnings --emit=metadata \
            --out-dir "$CARGO_TARGET_DIR/lint" rust/sweepdeck-accelerator/src/lib.rs
    else
        "$cargo_command" fmt --manifest-path rust/sweepdeck-accelerator/Cargo.toml -- --check
        "$cargo_command" clippy --manifest-path rust/sweepdeck-accelerator/Cargo.toml --release --all-targets --locked -- -D warnings
    fi
    if [[ "$command_name" == "test" ]]; then
        "$cargo_command" test --manifest-path rust/sweepdeck-accelerator/Cargo.toml --locked
    fi
    "$cargo_command" build --manifest-path rust/sweepdeck-accelerator/Cargo.toml --release --locked
fi

frameworks="$(dirname "$toolchain_usr")/Library/Developer/Frameworks"
if [[ "$command_name" == "test" && -d "$frameworks/Testing.framework" ]]; then
    testing_flags+=(--disable-xctest --enable-swift-testing --no-parallel)
    testing_support_flags+=(-Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
    if [[ -d "$frameworks/_Testing_Foundation.framework" && ! -d "$frameworks/_Testing_Foundation.framework/Modules" ]]; then
        testing_support_flags+=(-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays)
        echo "Disabling missing Testing/Foundation overlay for this test build." >&2
    fi
fi

# Run the AppKit appearance and presentation regressions in isolated Swift
# Testing processes. This keeps them separate from the core suite and avoids
# XCTest's crashing AppKit teardown path on hosted macOS runners.
if [[ "$command_name" == "test" ]]; then
    has_explicit_selection=false
    has_coverage=false
    expect_filter_value=false
    for argument in "$@"; do
        case "$argument" in
            --filter)
                has_explicit_selection=true
                expect_filter_value=true
                ;;
            --filter=*)
                has_explicit_selection=true
                ;;
            --test-product|--test-product=*|--list-tests|--help|-h|list|help) has_explicit_selection=true ;;
            --enable-code-coverage) has_coverage=true ;;
            *)
                if [[ "$expect_filter_value" == true ]]; then
                    expect_filter_value=false
                fi
                ;;
        esac
    done

    if [[ "$has_explicit_selection" == false ]]; then
        test_targets=(SweepdeckCoreTests SweepdeckAppearanceTests SweepdeckPresentationTests)
        if [[ "$has_coverage" == true ]]; then
            # SwiftPM writes one coverage report per invocation; keep the
            # core suite last so the project's core coverage gate sees it.
            test_targets=(SweepdeckAppearanceTests SweepdeckPresentationTests SweepdeckCoreTests)
        fi
        for test_target in "${test_targets[@]}"; do
            echo "Running $test_target in an isolated Swift Testing process." >&2
            swift test --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security \
                ${extra_flags[@]+"${extra_flags[@]}"} ${testing_support_flags[@]+"${testing_support_flags[@]}"} \
                ${testing_flags[@]+"${testing_flags[@]}"} --filter "$test_target" "$@"
        done
        exit 0
    fi
fi

exec swift "$command_name" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security \
    ${extra_flags[@]+"${extra_flags[@]}"} ${testing_support_flags[@]+"${testing_support_flags[@]}"} \
    ${testing_flags[@]+"${testing_flags[@]}"} "$@"
