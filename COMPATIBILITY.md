# Compatibility

| Version | Build target | Verification |
|---|---|---|
| macOS 15 | Minimum deployment target | 37 tests and release build passed with Swift 6.2 on the `macos-15` GitHub Actions runner ([run #62](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39503283738)); interactive UI runtime not checked |
| macOS 26 | Latest-toolchain CI lane | 37 tests and release build passed with Swift 6.4.1 on the `macos-26` runner ([run #62](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39503283738)); interactive UI runtime not checked |
| macOS 26.6.2, arm64 | Local host | Build/test/launch evidence recorded below when verified |
| macOS 27 | Future compatibility target | Not tested; no claim of verified support |
| Intel / other versions | Not a product target | Not tested |

Observed local toolchain: Swift 6.2 (`swiftlang-6.2.0.19.9`), macOS SDK 26.0,
Command Line Tools selected. No active full Xcode and no signing identities.
Use ad-hoc local signing. No App Store membership needed.

The package keeps Swift tools version 6.2 as its minimum. CI also exercises the
latest stable Swift.org toolchain (6.4.1) against the macOS 26 SDK, so newer
compiler compatibility is checked without raising the minimum developer toolchain.

## Host toolchain workarounds

The installed SwiftPM `PackageDescription` private interface was dated 2024 while
the public interface/library were from 2025, producing missing API/linker errors.
The installed Swift include directory also contained duplicate SwiftBridging module
definitions from different tool releases. `scripts/swift.sh` detects these exact
conditions and uses local `.build` copies/VFS overlays. Installed files are untouched.
The wrapper explicitly locates the CLT Testing framework when it is present and
uses Swift Testing without requiring XCTest. All generated files stay ignored.

Reinstalling/updating Command Line Tools or Xcode may resolve the underlying
installation, but that is outside this app's development workflow and was not done.

## API strategy

SwiftUI/AppKit with a macOS 15 deployment floor, Foundation Trash/coordinator,
POSIX lstat metadata, public Mach memory/CPU statistics, sysctl swap, and ProcessInfo
thermal state. Missing capabilities are shown as unavailable or rejected for cleanup.
No private API, cached directory-layout-based app uninstalling or SDK 27 dependency.

## Verification record

See Docs/VALIDATION.md for exact commands, results, manual checks and limitations.
GitHub Actions run #62 verifies the 37-test suite and release compilation on both the `macos-15`
baseline and the `macos-26` latest-toolchain lane. It does not verify interactive
launch, permissions prompts or visual UI behavior on either runner.
