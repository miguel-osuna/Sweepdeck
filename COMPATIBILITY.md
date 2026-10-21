# Compatibility

| Version | Build target | Verification |
|---|---|---|
| macOS 15 | Minimum deployment target | 48 tests, 87.5% core executable-line coverage and release build passed with Swift 6.2 on the `macos-15` runner ([rebased PR run 39624090617](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39624090617)); interactive UI runtime not checked |
| macOS 26 | Latest stable Swift toolchain lane | 48 tests, 87.5% core executable-line coverage and release build passed with Swift 6.4.1 on the `macos-26` runner ([rebased PR run 39624090617](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39624090617)); interactive UI runtime not checked |
| macOS 27 preview | Preview compatibility lane | 48 tests, 87.5% core executable-line coverage and release build passed on the Xcode 27 preview runner ([rebased PR run 39624090617](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39624090617)). An earlier run on the prior revision exited with signal 11 in `swiftpm-testing-helper` during `SweepdeckAppearanceTests` ([run 39570272638](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39570272638)); the rebased revision passes. Interactive UI runtime not checked |
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
release-shaped 0.1.0 candidate archive built on the disposable macOS 26 Apple Silicon
runner and its SHA-256 (`152f232d2aa7b0df502f341cac3bd2c00773bea68c5b32e8f21eac47b6225ab7`)
matched its sidecar. In [Homebrew candidate run 39569344355](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39569344355),
`brew audit --cask --strict`, `brew style --cask`, install, installed-bundle inspection,
and uninstall passed using a temporary local tap. `brew info --cask` reported the
Sweepdeck 0.1.0 app, and inspection confirmed the expected ARM64 executable and app
bundle. Homebrew's quarantine attribute remained present.

Gatekeeper did not pass: `spctl --assess --type execute --verbose=4` reported
`/Applications/Sweepdeck.app: rejected` with exit status 3. Launch Services did not
return within 15 seconds and no Sweepdeck process appeared. The runner then removed
the app with Homebrew uninstall. This was a release-shaped candidate ZIP from a
temporary local file URL, not a public GitHub Release asset; the recorded checksum is
not the hash for a published release. The versioned GitHub Release asset and public
cask remain unpublished. Developer ID signing and notarization are not being added
for this release attempt, and this candidate is not release-ready.
A repeat in [candidate run 39570883868](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39570883868)
passed the same Homebrew checks and reproduced the quarantine rejection and failed
first-launch result after the smoke command was bounded.
A third check in [candidate run 39571447748](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39571447748)
again passed Homebrew audit, style, install, bundle inspection, and uninstall while
preserving quarantine; Gatekeeper rejected the app (exit status 3), Launch Services
timed out after 15 seconds, and no app process appeared.
A fourth check after merging the main-branch test-runner fix, in [candidate run 39608770720](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39608770720),
again passed audit, style, install, bundle inspection, and uninstall; quarantine
remained present, Gatekeeper rejected the app (exit status 3), Launch Services timed
out after 15 seconds, and no app process appeared.
A fifth check after rebasing onto the appearance fix on `main`, in [candidate run 39624090614](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39624090614),
again passed audit, style, install, bundle inspection, and uninstall while retaining
quarantine; Gatekeeper rejected the app (exit status 3), Launch Services timed out after
15 seconds, and no app process appeared.
A sixth check on the updated PR branch, in [candidate run 39627722049](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39627722049),
built and verified the 0.1.0 candidate archive and sidecar checksum
(`30eba142232435ee01dcaed1639a0f5f60d15696fa2056e209f069bf9876cba0`). Homebrew
audit/style, install, bundle inspection, and uninstall passed with quarantine intact;
Gatekeeper rejected the app (status 3), Launch Services timed out after 15 seconds,
and no app process appeared. This is a candidate artifact checksum, not the checksum
of a published release asset.

App Store submission is not required by the cask format, and notarization is not a
cask-format requirement. Homebrew's current macOS policy does require executable
cask artifacts to pass its Gatekeeper checks. If the quarantined candidate fails,
release readiness remains closed because the current build cannot pass Gatekeeper and
first-launch checks. No quarantine removal, Gatekeeper override, or cask-script bypass
is acceptable.

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
GitHub Actions run #94 historically verified the 43-test suite, 80% core coverage
floor and release compilation on `macos-15`, `macos-26`, and the macOS 27/Xcode 27
preview lane. On shared commit `47cc1b4`, stable lanes passed in push run
#39570272638 and the duplicate pull-request run #39570279509 passed the full matrix;
the push run's Xcode 27 test helper exited with signal 11 during
`SweepdeckAppearanceTests`. The preview result is inconsistent. These CI runs do
not verify interactive launch, permissions prompts or visual UI behavior on any
runner.
