# Compatibility

| Version | Build target | Verification |
|---|---|---|
| macOS 15 | Minimum deployment target | 43 tests, 80% core coverage floor and release build passed with Swift 6.2 on the `macos-15` runner ([run #94](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39523586559)); interactive UI runtime not checked |
| macOS 26 | Latest stable Swift toolchain lane | 43 tests, 80% core coverage floor and release build passed with Swift 6.4.1 on the `macos-26` runner ([run #94](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39523586559)); interactive UI runtime not checked |
| macOS 27 preview | Preview compatibility lane | 43 tests, 80% core coverage floor and release build passed with Swift 6.4 and Xcode 27 preview on `xcode-27` ([run #94](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39523586559)); preview evidence only, interactive UI runtime not checked |
| macOS 26.6.2, arm64 | Local host | 43 tests, 85.4% core executable-line coverage and release bundle build passed; see `Docs/VALIDATION.md` for fixture checks and outstanding pixel-level visual verification |
| Intel / other versions | Not a product target | Not tested |

Observed local toolchain: Swift 6.2 (`swiftlang-6.2.0.19.9`), macOS SDK 26.0,
Command Line Tools selected. No active full Xcode and no signing identities.
Use ad-hoc local signing. No App Store membership needed.

## Homebrew distribution evidence

The intended distribution is an owner-managed public tap at
`github.com/miguel-osuna/homebrew-tap`, using a versioned GitHub Release ZIP and its
SHA-256 checksum. The target install command is
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew's fully qualified install
trusts that cask only. A short-name install requires `brew tap miguel-osuna/tap`,
`brew trust --cask miguel-osuna/tap/sweepdeck`, then
`brew install --cask sweepdeck`.

As of 2026-10-21, the public tap and first app release are not yet published. The
current release build is ad-hoc signed, and no Homebrew-quarantined first launch has
been verified on a disposable Apple Silicon Mac. Release workflow validation is
being added for a versioned candidate built on macOS 15 and tested on a disposable
macOS 26 Apple Silicon runner;
the test will inspect the installed bundle, run Homebrew audit/style/install/uninstall,
preserve quarantine, assess Gatekeeper, and attempt first launch with isolated app
state. None of those new distribution checks is recorded as passed yet.

App Store submission is not required by the cask format, and notarization is not a
cask-format requirement. Homebrew's current macOS policy does require executable
cask artifacts to pass its Gatekeeper checks. If the quarantined candidate fails,
release readiness remains closed until a signing/notarization decision is made; no
quarantine removal, Gatekeeper override, or cask-script bypass is acceptable.

Official `homebrew/cask` inclusion is not being submitted. At the time of review,
the canonical Sweepdeck repository was one day old with 0 stars, forks, and watchers.
Homebrew's current policy normally requires at least 30 forks or watchers or 75 stars,
and a self-submission normally requires 90 forks or watchers or 225 stars. A repository
under 30 days old is normally ineligible. Those criteria do not restrict owner-managed
third-party taps.

The package keeps Swift tools version 6.2 as its minimum. CI exercises the
latest stable Swift.org toolchain (6.4.1) on macOS 26 and a separate Swift 6.4 /
Xcode 27 preview lane, without raising the minimum developer toolchain. The
preview lane is early compatibility evidence and is not a stable macOS 27 release
support claim.

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
GitHub Actions run #94 verifies the 43-test suite, 80% core coverage floor and
release compilation on `macos-15`, `macos-26`, and the macOS 27/Xcode 27 preview
lane. It does not verify interactive launch, permissions prompts or visual UI
behavior on any runner.
