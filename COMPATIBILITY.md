# Compatibility

Sweepdeck targets Apple Silicon Macs running macOS 15 or later. The minimum deployment
target describes the supported OS floor; use the verification below as the evidence for
the builds and runners that were actually checked.

## Continuous integration

| Runner | Toolchain | Result |
|---|---|---|
| macOS 15 | Swift 6.2 | Release verification, tests, coverage gate, and app build passed in [release run 39658605258](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39658605258). |
| macOS 26 | Swift 6.4.1 | Release verification, tests, coverage gate, and app build passed in [release run 39658605258](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39658605258). |
| macOS 27 preview | Xcode 27 preview | Release verification, tests, coverage gate, and app build passed in [release run 39658605258](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39658605258). |
| Intel Macs / other macOS versions | — | Not tested; Intel is not a product target. |

These release-matrix results describe the published 0.1.0 source revision. The selected
icon and app-bundle integration in [PR #12](https://github.com/miguel-osuna/Sweepdeck/pull/12)
also passed the macOS 15, macOS 26, and macOS 27 preview build lanes in
[Build and test run 39662470145](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39662470145),
and the disposable Homebrew candidate smoke in
[run 39662470012](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39662470012).
The icon-bearing 0.2.0 candidate then passed the release verification matrix, candidate
build, and disposable Homebrew smoke in [release run 39664467890](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39664467890).
That candidate is not yet a published release; its protected release job is waiting for
reviewer approval.

## Homebrew and Gatekeeper evidence

The [0.1.0 GitHub Release](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.1.0)
contains an app-only ZIP and a verified SHA-256 sidecar. The archive digest is
`383034386df5a692a687df6ff1b70ea088791df304dd8de568069da2fd097789`.
The release's [Homebrew candidate check](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39658605258)
ran on a disposable macOS 26 Apple Silicon runner. Homebrew audit and style, install,
installed-bundle and version inspection, quarantine inspection, and uninstall passed.
Homebrew preserved quarantine. The downloaded archive contained only `Sweepdeck.app`.

The app's ad-hoc code signature verified. Gatekeeper's
`spctl --assess --type execute --verbose=4` rejected the quarantined app with status 3.
The captured first-launch window said **“Sweepdeck” Not Opened** because Apple could not
verify it was free of malware; the buttons were **Move to Trash** and **Done**. Launch
Services timed out after 15 seconds (status 124), though the app process was observed
with its isolated temporary state directory. The runner did not approve the app or
verify a successful post-approval launch. It did not remove quarantine or disable
Gatekeeper.

The 0.2.0 candidate's archive sidecar SHA-256 was verified as
`e31d64f80948461fe0f92d5c482c8f11c8f364ca81f8c326a40f8db8d2dbd760`. The archive
contains only `Sweepdeck.app`, including `Contents/Resources/Sweepdeck.icns`. Its
disposable macOS 26 Apple Silicon Homebrew candidate check passed audit, style, install,
bundle/version and quarantine inspection, first-launch reporting, and uninstall. The
captured first-launch screen again showed **“Sweepdeck” Not Opened**; the candidate
check did not approve the app or verify a successful post-approval launch. The release
workflow is waiting for the required environment reviewer, so the archive and checksum
are not public yet.

The cask is not yet public. Tap PR [#1](https://github.com/miguel-osuna/homebrew-tap/pull/1)
currently provides the validation workflow and neutral tap description. The cask will
be added after the 0.2.0 icon-bearing release is public, then the tap workflow will test
the actual public release URL. The intended install command is
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew trusts only that fully
qualified cask for the command. Short-name install requires `brew tap miguel-osuna/tap`,
`brew trust --cask miguel-osuna/tap/sweepdeck`, then `brew install --cask sweepdeck`.

This owner-managed tap keeps the Gatekeeper warning visible. The cask will install only
the app, with no `zap` stanza or cleanup scripts; uninstall preserves app preferences
and history. The current build does not pass Gatekeeper and does not meet the official
Homebrew cask executable requirement, so official-cask inclusion is not being pursued.
App Store submission and notarization are not requirements of the cask format.

At the 2026-10-21 official Homebrew eligibility check, the canonical Sweepdeck
repository had 0 stars, forks, and watchers and was one day old. The shared package
policy normally requires 30 forks or watchers or 75 stars, increased to 90 forks or
watchers or 225 stars for a self-submission; repositories under 30 days old are normally
ineligible. These criteria do not restrict an owner-managed tap.

## Local workspace

Observed host: macOS 26.6.2, arm64, Swift 6.2, SDK 26.0, Command Line Tools selected.
No active full Xcode or signing identity was present. Ad-hoc local signing is used; no
App Store membership or paid signing account is needed to build.

The app bundle build was attempted after adding the icon resource but stopped before
compilation because Rust 1.99.1, selected by `rust-toolchain.toml`, is not installed in
this workspace. No Rust toolchain, Xcode/Command Line Tools, macOS settings, or signing
identity was changed. The 0.1.0 source build passed in CI, and the icon-bearing build
passed in PR #12 and the 0.2.0 candidate release run. Local Homebrew and taps were not
modified.

## Verification details

See [Docs/VALIDATION.md](Docs/VALIDATION.md) for the fixture-level safety checks and
historical local validation. The app uses SwiftUI/AppKit, Foundation Trash and file
coordination, POSIX `lstat` metadata, public Mach memory/CPU statistics, `sysctl` swap,
and `ProcessInfo` thermal state. No private API or SDK 27 dependency is used.
