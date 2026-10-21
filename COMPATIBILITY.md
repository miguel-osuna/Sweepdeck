# Compatibility

| Version | Build target | Verification |
|---|---|---|
| macOS 15 | Minimum deployment target | 48 tests, 87.5% core executable-line coverage and release build passed with Swift 6.2 on the `macos-15` runner ([PR run 39628624761](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39628624761)); interactive UI runtime not checked |
| macOS 26 | Latest stable Swift toolchain lane | 48 tests, 87.5% core executable-line coverage and release build passed with Swift 6.4.1 on the `macos-26` runner ([PR run 39628624761](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39628624761)); interactive UI runtime not checked |
| macOS 27 preview | Preview compatibility lane | 48 tests, 87.5% core executable-line coverage and release build passed on the Xcode 27 preview runner ([PR run 39628624761](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39628624761)). An earlier run on the prior revision exited with signal 11 in `swiftpm-testing-helper` during `SweepdeckAppearanceTests` ([run 39570272638](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39570272638)); the rebased revision passes. Interactive UI runtime not checked |
| macOS 26.6.2, arm64 | Local host | 43 tests, 85.4% core executable-line coverage and release bundle build passed; see `Docs/VALIDATION.md` for fixture checks and outstanding pixel-level visual verification |
| Intel / other versions | Not a product target | Not tested |

Observed local toolchain: Swift 6.2 (`swiftlang-6.2.0.19.9`), macOS SDK 26.0,
Command Line Tools selected. No active full Xcode and no signing identities.
Use ad-hoc local signing. No App Store membership needed.

## Homebrew distribution evidence

The planned distribution is an owner-managed public tap at
`github.com/miguel-osuna/homebrew-tap`, using a versioned GitHub Release ZIP and its
SHA-256 checksum. The install command will be
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew trusts only that cask for
the fully qualified command. A short-name install requires `brew tap miguel-osuna/tap`,
`brew trust --cask miguel-osuna/tap/sweepdeck`, then `brew install --cask sweepdeck`.

On 2026-10-21, Homebrew's public cask and formula API endpoints for `sweepdeck` both
returned HTTP 404, so the token was available in those official namespaces at the time.
The owner tap's default branch had no `Casks/sweepdeck.rb`; its open PR contains the
validation workflow and product-neutral repository description. Token availability
does not make an unpublished install command usable.

The 0.1.0 candidate check, [Actions run 39642233429](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39642233429),
built the release-shaped 0.1.0 archive and verified its sidecar SHA-256
(`9741ddc4482f240704113b93d8d51e031a28d343fd8f1f44cc101bf6a694b269`). On the
disposable macOS 26 Apple Silicon runner, Homebrew strict audit and style passed;
install, bundle/version inspection, quarantine inspection, and uninstall also passed.
The installed artifact was only `Sweepdeck.app`; its executable was arm64 and the
Homebrew caveat appeared in `brew info --cask`. The app retained its Homebrew quarantine
attribute and `codesign --verify --strict` accepted its ad-hoc signature.

Gatekeeper's `spctl --assess --type execute --verbose=4` rejected the quarantined app
(status 3). The captured first-launch screen showed **“Sweepdeck” Not Opened** and
“Apple could not verify ‘Sweepdeck’ is free of malware,” with **Move to Trash** and
**Done** buttons. Launch Services timed out after 15 seconds (status 124), and the
Sweepdeck process was observed with its temporary state directory argument. Homebrew
uninstall removed `/Applications/Sweepdeck.app`. The runner did not approve the app or
verify a successful launch after approval. The screen is retained in the Actions run's
one-day artifact. This was a temporary local cask using a candidate ZIP; no public
release asset or tap cask was installed. The earlier style failure in
[run 39639700468](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39639700468)
was caused by stanza order in the generated cask and was corrected before the passing
run above.

The selected no-cost distribution path keeps quarantine intact and tells users that
macOS blocks the first open until they decide whether to approve Sweepdeck in System
Settings > Privacy & Security. Apple says **Open Anyway** is available for about an hour
after an attempted open; the candidate screen itself offered only **Move to Trash** and
**Done**. The cask will not remove quarantine, disable Gatekeeper, or automate that
choice. This is not a Gatekeeper pass and does not meet the official
`homebrew/cask` security requirement; official inclusion is not being pursued. App
Store submission and notarization are not requirements of the cask format. Cask
updates will be manual and reviewed through a tap pull request. The cask will install
only `Sweepdeck.app`, with no `zap` stanza or cleanup scripts, so uninstall leaves
Sweepdeck preferences and history intact.

The versioned GitHub Release and public cask are not yet published. The release
workflow still requires `RELEASE_READY=true` and a `release` GitHub Environment with
at least one required reviewer. It keeps the `main`-only rule, requires `0.1.0` for the
first public version, and holds publication behind the required-reviewer gate.

At the 2026-10-21 official eligibility check, Sweepdeck's canonical GitHub repository
had 0 stars, forks, and watchers and was one day old. Homebrew's [shared package
acceptance policy](https://docs.brew.sh/Package-Acceptance-Policy) normally requires
30 forks or watchers or 75 stars, increased to 90 forks or watchers or 225 stars for
a self-submission; repositories under 30 days old are normally ineligible. Those
criteria do not restrict the owner-managed tap.

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

On commit `916b829`, the pull-request build run [39628624761](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39628624761)
passed all three macOS lanes and release-tooling checks: 48 tests and 87.5% core
executable-line coverage per macOS lane. The duplicate push run
[39628613820](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39628613820)
passed the stable and preview lanes and release tooling, but the macOS 15 test command
exited with signal 11 after its appearance test passed; no recent XCTest or SwiftPM
helper crash report was found. This was not reproduced by the pull-request run on the
same commit.
