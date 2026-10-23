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
The icon-bearing 0.2.0 release then passed the release verification matrix, candidate
build, and disposable Homebrew smoke in [release run 39664467890](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39664467890).
The protected release job was approved by its required reviewer and completed
successfully.

The Sparkle updater changes in the current working tree built and passed the complete
Swift test matrix with Swift 6.2 and Sparkle 2.10.0 on macOS 26.6.2 arm64. Isolated
automatic 0.3.0-to-0.4.0 updates passed with both the existing production Keychain key
and a per-test ephemeral key. Sparkle installed on quit; the harness relaunched 0.4.0
and verified the launch marker, preserved appearance/history/state, signature, and
unchanged installed `/Applications/Sweepdeck.app`. The locally built 0.4.0 candidate
path also passed using a fresh ephemeral key. Automatic installation was enabled only
in temporary test bundles. The updated app's dashboard visibly reports `Version 0.4.0`,
and the user confirmed that the post-update Settings footer reports `0.4.0`. The manual
visual before/after preferences and history comparison remains unverified; the automated
state-file checks passed. Three earlier local attempts fetched the localhost appcast
without requesting the archive and timed out before installation; the UI bridge closed
during those attempts. A fresh run under the unique display name
`Sweepdeck Update Test DZc3Pp` also fetched the appcast but did not begin installation
before timing out at 0.3.0; the native UI bridge again failed to attach. The process
lookup now requests full-width `ps` output. The
historical CI rows above do not cover these updater changes; the updated CI and release
workflow paths have not yet run on GitHub. GitHub Pages is configured, but the workflow
has not deployed an appcast, so the new post-deploy smoke against the public feed and
GitHub Release ZIP is configured but cannot run until the first Sparkle-enabled release.

The release workflow now includes a disposable macOS gate for the exact candidate ZIP:
it signs a localhost feed with a per-run ephemeral key, verifies Sparkle installs the
candidate on quit, then launches the updated bundle and checks state preservation
before the protected publish job. This workflow change has not yet run on GitHub and
does not test quarantine or Gatekeeper.

The relaunch-deferral unit tests passed for active scan/preview/Trash states. A live
localhost deferral run then used only the harness-generated empty-directory fixture. The
update prompt offered 0.4.0 with automatic installation unchecked. I requested download
and relaunch while the UI reported an active scan; Sparkle stayed at “Ready to Install”
until the scan result was saved, then relaunched the test app at 0.4.0. The saved test
state retained its seeded Dark appearance and history entry, gained the completed scan
timestamp, and recorded both 0.3.0 and 0.4.0 launches. The updated bundle passed strict
code-signature verification. No files were selected or moved to Trash. Offline-feed and
tampered-archive signatures are rejected by the test tooling, but the corresponding
visible Sparkle UI failure dialogs remain unverified.

The localhost runs did not simulate a quarantined download or verify Gatekeeper behavior.
The current release remains ad-hoc signed and unnotarized, so the production bundle now
sets `SUAllowsAutomaticUpdates=false`. The Settings control is visible but disabled;
isolated test bundles explicitly override that value to exercise automatic installation.
Run a quarantined update test on a disposable macOS runner before allowing the control.
The release workflow run currently visible on GitHub predates these updater changes, and
the public appcast URL returns HTTP 404 until a Sparkle-enabled release publishes it. The
Homebrew tap remains at 0.3.0 with no `auto_updates` declaration. The signing key is in
the protected GitHub release environment and remains in the local Keychain. A local
plaintext recovery export with owner-only permissions was generated for the user to save
in their vault; vault storage is not yet confirmed, so an encrypted offline backup remains
an open release-readiness task. Sparkle recommends
Developer ID signing and notarization where possible
([Sparkle security guidance](https://sparkle-project.org/documentation/)). Apple explains
how notarization tickets inform Gatekeeper on first launch
([Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)).

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

The published [0.2.0 GitHub Release](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.2.0)
includes its archive and `.sha256` sidecar. The downloaded public archive matches both
the sidecar and GitHub's recorded asset digest:
`e31d64f80948461fe0f92d5c482c8f11c8f364ca81f8c326a40f8db8d2dbd760`. The archive
contains only `Sweepdeck.app`, including `Contents/Resources/Sweepdeck.icns`. Its
disposable macOS 26 Apple Silicon Homebrew candidate check passed audit, style, install,
bundle/version and quarantine inspection, first-launch reporting, and uninstall. The
captured first-launch screen again showed **“Sweepdeck” Not Opened**; the candidate
check did not approve the app or verify a successful post-approval launch.
Tap PR [#2](https://github.com/miguel-osuna/homebrew-tap/pull/2) passed the tap's
disposable Apple Silicon macOS workflow ([run 39676510862](https://github.com/miguel-osuna/homebrew-tap/actions/runs/39676510862)):
strict audit, style, install, installed app/version and quarantine inspection,
Gatekeeper/first-launch reporting, and uninstall all passed.
The quarantine attribute remained on the installed app, its ad-hoc signature verified,
and Gatekeeper rejected unattended launch with status 3. The captured dialog again said
**“Sweepdeck” Not Opened** because Apple could not verify the app was free of malware.
Launch Services timed out after 15 seconds (status 124), but the Sweepdeck process was
observed with the runner's isolated temporary state directory. The check did not approve
the app or remove quarantine; uninstall then removed the app from `/Applications`.

Tap PR [#1](https://github.com/miguel-osuna/homebrew-tap/pull/1) added the validation
workflow and a product-neutral repository description. Tap PR [#2](https://github.com/miguel-osuna/homebrew-tap/pull/2)
published the cask on the tap's default branch. The install command is
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew trusts only that fully
qualified cask for the command. Short-name install requires `brew tap miguel-osuna/tap`,
`brew trust --cask miguel-osuna/tap/sweepdeck`, then `brew install --cask sweepdeck`.

This owner-managed tap keeps the Gatekeeper warning visible. The cask installs only the
app, with no `zap` stanza or cleanup scripts; uninstall preserves app preferences and
history. The current build does not pass Gatekeeper and does not meet the official
Homebrew cask executable requirement, so official-cask inclusion is not being pursued.
App Store submission and notarization are not requirements of the cask format.

At the 2026-10-21 official Homebrew eligibility check, the canonical Sweepdeck
repository had 0 stars, forks, and watchers and was one day old. The shared package
policy normally requires 30 forks or watchers or 75 stars, increased to 90 forks or
watchers or 225 stars for a self-submission; repositories under 30 days old are normally
ineligible. These criteria do not restrict an owner-managed tap.

### User approval procedure

For a user who trusts the downloaded release, Apple's documented one-time approval is:
click **Done** in the warning, open **System Settings > Privacy & Security**, scroll to
**Security**, click **Open Anyway** for Sweepdeck, then click **Open** in the repeated
warning. Apple says this saves a per-app exception for future launches. This procedure
is Apple guidance, not a successful post-approval launch observed by the candidate
check; see [Apple's security guidance](https://support.apple.com/en-au/102445).

The current app-only ZIP is ad-hoc signed without an Apple-issued Developer ID
signature or notarization ticket. Packaging the same app in a DMG would not change its
Gatekeeper status. A release that avoids this malware-verification block for users
requires Developer ID signing and notarization, followed by a fresh quarantine and
first-launch check on a disposable supported Mac. Apple currently lists the Developer
Program at USD 99 per year in the United States, with regional pricing and limited
organization fee waivers (see [membership
terms](https://developer.apple.com/help/account/membership/program-enrollment)).
macOS may still ask users to confirm opening a downloaded app the first time.

Version [0.3.0](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.3.0) is the
first release with both the app-only ZIP and optional drag-to-Applications DMG. The
complete [release run 39686586148](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39686586148)
passed main verification, candidate packaging, disposable DMG inspection, Homebrew
checks, and publication. The ZIP and DMG plus both public SHA-256 sidecars were
independently downloaded and verified. ZIP SHA-256:
`ba4c944c4a128a508465b0c7659c60359220c1585da7f6c0f89c4072141ccf6e`; DMG SHA-256:
`62e81604c21fe34be3900a1753a9ee6cfb55591edfb0fba70eb486f5d41853c4`.

The release workflow's disposable Apple Silicon check verified the DMG checksum,
read-only image mount, app version/signature/icon, Applications shortcut, and
`INSTALL.txt`. It did not download the public DMG, simulate its quarantine state, or
verify the DMG route's first launch. The exact candidate ZIP passed Homebrew audit,
style, install, bundle/version/quarantine inspection, Gatekeeper reporting, and
uninstall. Its ad-hoc signed app remained quarantined; Gatekeeper rejected unattended
launch with status 3, Launch Services timed out after 15 seconds (status 124), and no
app process was observed. The workflow did not simulate user approval or claim a
successful post-approval launch.

The tap's [PR #3](https://github.com/miguel-osuna/homebrew-tap/pull/3) clarified the
one-time approval instructions. [Tap PR #4](https://github.com/miguel-osuna/homebrew-tap/pull/4) updated the cask
to 0.3.0 with the verified ZIP checksum after its disposable macOS checks passed in
[tap run 39687605169](https://github.com/miguel-osuna/homebrew-tap/actions/runs/39687605169).
The run passed strict audit, style, install, installed-bundle/quarantine inspection,
Gatekeeper reporting, and uninstall.

## Local workspace

Observed host: macOS 26.6.2, arm64, Swift 6.2, SDK 26.0, Command Line Tools selected.
No active full Xcode or signing identity was present. Ad-hoc local signing is used; no
App Store membership or paid signing account is needed to build.

The app bundle build was attempted after adding the icon resource but stopped before
compilation because Rust 1.99.1, selected by `rust-toolchain.toml`, is not installed in
this workspace. No Rust toolchain, Xcode/Command Line Tools, macOS settings, or signing
identity was changed. The 0.1.0 source build passed in CI, and the icon-bearing build
passed in PR #12 and the 0.2.0 release run. After the 0.3.0 tap update was
published, this host's local tap checkout was fast-forwarded and the existing
cask was upgraded from 0.2.0 to 0.3.0 with:

`HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask miguel-osuna/tap/sweepdeck`.

Homebrew printed the approval caveat. The installed bundle reports version
0.3.0 and retains `com.apple.quarantine`. No other casks or formulae were
changed, and the app was not opened or approved locally.

## Verification details

See [Docs/VALIDATION.md](Docs/VALIDATION.md) for the fixture-level safety checks and
historical local validation. The app uses SwiftUI/AppKit, Foundation Trash and file
coordination, POSIX `lstat` metadata, public Mach memory/CPU statistics, `sysctl` swap,
and `ProcessInfo` thermal state. No private API or SDK 27 dependency is used.
