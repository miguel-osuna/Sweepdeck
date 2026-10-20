#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/local-toolchain
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"

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
frameworks="$(dirname "$toolchain_usr")/Library/Developer/Frameworks"
if [[ "$command_name" == "test" && -d "$frameworks/Testing.framework" ]]; then
    extra_flags+=(--disable-xctest --enable-swift-testing --no-parallel -Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks")
    if [[ -d "$frameworks/_Testing_Foundation.framework" && ! -d "$frameworks/_Testing_Foundation.framework/Modules" ]]; then
        extra_flags+=(-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays)
        echo "Disabling missing Testing/Foundation overlay for this test build." >&2
    fi
fi
exec swift "$command_name" --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security ${extra_flags[@]+"${extra_flags[@]}"} "$@"
