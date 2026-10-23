<div align="center">
  <img src="Resources/SweepdeckIcon.png" alt="Sweepdeck app icon" width="136">
  <h1>Sweepdeck</h1>
  <p><strong>Know what's using your storage. Review every cleanup before it reaches Trash.</strong></p>
  <p>
    <a href="https://github.com/miguel-osuna/Sweepdeck/actions/workflows/build.yml"><img alt="Build and test" src="https://github.com/miguel-osuna/Sweepdeck/actions/workflows/build.yml/badge.svg?branch=main"></a>
    <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/github/license/miguel-osuna/Sweepdeck"></a>
    <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-000000?logo=apple">
  </p>
</div>

Sweepdeck is a free, native macOS utility for inspecting local storage and reviewing
individual files before moving them to Trash. No accounts, subscriptions, telemetry,
or background indexing. The built-in updater is configured for the first Sparkle-enabled
release, using a signed GitHub Pages feed and the versioned GitHub Release ZIP. Existing
0.3.0 and earlier installations will need to install that release manually once.
Automatic checks require opt-in. Automatic installation is disabled until the
quarantined update path passes Gatekeeper; while it is disabled, each installation
requires user approval. Sweepdeck sends no system profile.

## What it does

- Shows storage capacity, recommendations, and a partial explorer for authorized folders.
- Scans only folders you choose for old installers, Downloads items, logs, and large files.
- Lets you inspect each candidate, preview the exact paths, and choose what to move to Trash.
- Keeps a bounded local history and shows CPU, memory, swap, storage, and thermal readings.

## Safety by design

- Nothing scans at launch. You choose each folder before scanning it.
- The selection starts empty. Every category requires review.
- A five-minute preview is revalidated before each file moves to macOS Trash.
- Sweepdeck never permanently deletes files, empties Trash, or moves directories.
- Protected locations, hidden files, repositories, symlinks, packages, and cloud-managed files are excluded.

See [SAFETY.md](SAFETY.md) for the full eligibility rules and limitations.

## Scope

Sweepdeck handles individual regular files in explicitly authorized local folders.
File age and size help find items to review; they do not prove a file is disposable.
It does not remove directories or apps, find duplicates, mutate developer caches, scan
external or network volumes, or terminate processes. The folder explorer is partial
and uses the bounded scan results.

## Download and Homebrew

[Version 0.3.0 is available on GitHub Releases](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.3.0).
It includes an app-only ZIP and an optional direct-download DMG. Each asset has a
published SHA-256 sidecar. The independently verified SHA-256 values are:

- ZIP: `ba4c944c4a128a508465b0c7659c60359220c1585da7f6c0f89c4072141ccf6e`
- DMG: `62e81604c21fe34be3900a1753a9ee6cfb55591edfb0fba70eb486f5d41853c4`

Version 0.3.0 does not include the updater. Install the first updater-enabled release
manually; later versions can be installed in place through Sweepdeck.

The [DMG download](https://github.com/miguel-osuna/Sweepdeck/releases/download/v0.3.0/Sweepdeck-0.3.0-macOS.dmg)
contains the same app, an Applications shortcut, and `INSTALL.txt` for drag-to-Applications
setup. It does not change Gatekeeper's first-launch check described below. Homebrew
continues to install the app-only ZIP.

The owner-managed Homebrew tap is maintained at
[`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap). The
Sweepdeck cask was published in [tap PR #2](https://github.com/miguel-osuna/homebrew-tap/pull/2)
and updated to 0.3.0 in [tap PR #4](https://github.com/miguel-osuna/homebrew-tap/pull/4).
Install with:

```sh
brew install --cask miguel-osuna/tap/sweepdeck
```

Homebrew's [tap trust behavior](https://docs.brew.sh/Tap-Trust) trusts only the
fully qualified cask above; it does not trust every formula and cask in the tap.

Installing by the short name requires these setup steps first:

```sh
brew tap miguel-osuna/tap
brew trust --cask miguel-osuna/tap/sweepdeck
brew install --cask sweepdeck
```

The cask installs only `Sweepdeck.app` and has no `zap` stanza or cleanup scripts.
Uninstall leaves Sweepdeck preferences and history in place.

### Gatekeeper on first launch

The free release is ad-hoc signed, without an Apple-issued Developer ID signature or
notarization ticket. In the disposable macOS 26 check, Gatekeeper blocked the first
open and said Apple could not verify Sweepdeck is free of malware. The dialog offered
**Move to Trash** or **Done**. Homebrew preserves quarantine, and the cask does not
bypass Gatekeeper or automate an approval.

The 0.3.0 release's [captured first-launch screen](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39686586148)
shows the same warning. That check did not approve the app or verify a successful
post-approval launch. The disposable workflow inspected the DMG layout but did not
download the DMG or test its quarantine/first-launch behavior separately.

If you downloaded Sweepdeck from the official release or installed it from the tap,
and you trust that source, macOS provides a one-time, per-app approval:

1. Click **Done** in the warning. **Move to Trash** removes the app.
2. Open **System Settings > Privacy & Security**, scroll to **Security**, and click
   **Open Anyway** for Sweepdeck.
3. When the warning appears again, click **Open** if you still want to run it.

macOS saves this exception for Sweepdeck, so later launches work by double-clicking
the app. This does not turn off Gatekeeper for other apps. Apple's [security
guidance](https://support.apple.com/en-au/102445) explains the approval. The DMG
simplifies copying the app into Applications, but it does not add an Apple-issued
Developer ID signature or notarization ticket, so it will not remove this warning.
Removing this malware-verification warning for all users requires Developer ID signing
and notarization through the Apple Developer Program, currently USD 99 per year in the
United States. macOS may still show its ordinary first-download confirmation.
See [compatibility evidence](COMPATIBILITY.md) for the checks completed on this
release.

## Build from source

Requires Apple Silicon, macOS 15+, Swift 6.2, the macOS SDK, and Rust 1.99.1. Xcode
or matching Command Line Tools are sufficient. Install Rust with `rustup`; the checked-in
`rust-toolchain.toml` selects the compiler plus `clippy` and `rustfmt`. The first Rust
use can download these components. Sparkle 2.10.0 is fetched as a checksum-pinned
official binary framework by `scripts/prepare-sparkle.sh`; Sweepdeck has no third-party
Cargo crate dependencies.

```sh
bash scripts/swift.sh test
bash scripts/build-app.sh
open dist/Sweepdeck.app
```

The build creates a locally ad-hoc signed app. No developer identity, provisioning
profile, or App Store membership is required to build it. Public distribution may show
the Gatekeeper approval described above.

## First use

1. Choose a specific folder using **Choose Folder**. Nothing scans at startup.
2. Select **Scan Mac**. Sweepdeck scans only folders you authorized.
3. Open **Smart Cleanup**, expand a category, inspect the files, and select only what you no longer need.
4. Choose **Preview Cleanup** and review every path and rejected item.
5. Acknowledge the review and explicitly choose **Move Files to Trash**.

Finder's Trash can restore moved files. Moving files to Trash usually does not
immediately free disk space.

## Local data and privacy

Preferences and history live in
`~/Library/Application Support/Sweepdeck/state.json`. History can contain file paths
and retains at most 50 operations / 1,000 item results. Diagnostics export contains
counts and OS/app versions, not paths or file contents. If you enable update checks,
Sweepdeck contacts the public GitHub release feed. It sends no system profile.

For isolated GUI validation, pass
`--sweepdeck-state-directory <temporary-directory>` to the app at launch. This
redirects only preferences and history; it does not add folders, scan, or authorize
cleanup.

## Documentation

- [Compatibility and verification](COMPATIBILITY.md)
- [Release process](Docs/RELEASING.md)
- [Architecture](ARCHITECTURE.md)
- [Safety and limitations](SAFETY.md)
- [Contributing](CONTRIBUTING.md)
- [Roadmap](Docs/ROADMAP.md)
- [License](LICENSE)
