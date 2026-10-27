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

Sweepdeck is a free, native macOS app for finding files you may no longer need and
reviewing them before moving them to Trash. It scans only folders you choose. There
are no accounts, subscriptions, telemetry, or background scans.

## Safety first

- The initial selection is empty. Review individual files and preview every path.
- Sweepdeck moves approved files to macOS Trash; it never permanently deletes files.
- Protected locations, hidden files, repositories, packages, and cloud-managed files
  are excluded.
- Age and size help find files to review; they do not prove a file is disposable.

See [SAFETY.md](SAFETY.md) for the full rules and limitations.

## Download

The latest release is [Sweepdeck 0.4.0](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.4.0).
Download the app-only ZIP, or use the [DMG](https://github.com/miguel-osuna/Sweepdeck/releases/download/v0.4.0/Sweepdeck-0.4.0-macOS.dmg)
to copy Sweepdeck into Applications.

The built-in updater arrived in 0.4.0. Versions 0.3.0 and earlier do not have an
updater, so install 0.4.0 manually once. In 0.4.0, you can check for updates in the
app or opt into automatic checks; Sweepdeck asks before installing an update.

### Homebrew

The Homebrew tap is maintained in [`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap).
Its cask currently installs 0.3.0. Use the GitHub download above for the updater-enabled
0.4.0 release. Homebrew install command:

```sh
brew install --cask miguel-osuna/tap/sweepdeck
```

The fully qualified command avoids adding trust for every package in the tap. The cask
installs only `Sweepdeck.app`; uninstalling leaves preferences and history in place.

### Gatekeeper

The free release is ad-hoc signed and is not notarized. macOS may show a warning on
first launch. If you downloaded Sweepdeck from the official release or installed it
from the tap and trust that source, you can approve Sweepdeck for your Mac in **System
Settings > Privacy & Security**. See [Apple's guidance](https://support.apple.com/en-au/102445)
and the [compatibility report](COMPATIBILITY.md). The DMG makes copying the app easier;
it does not change Gatekeeper's check.

## Build from source

Requires Apple Silicon, macOS 15+, Swift 6.2, the macOS SDK, and Rust 1.99.1. Install
Rust with `rustup`; the checked-in toolchain file selects the required compiler and
components. The build downloads the checksum-pinned Sparkle 2.10.0 framework.

```sh
bash scripts/swift.sh test
bash scripts/build-app.sh
open dist/Sweepdeck.app
```

The local build is ad-hoc signed and does not require a developer identity or
provisioning profile.

## First scan

1. Choose a folder. Nothing scans at launch.
2. Select **Scan Mac**.
3. Inspect candidates and select only files you want to remove.
4. Preview the exact paths, then confirm moving them to Trash.

Finder's Trash can restore moved files. Moving files to Trash may not immediately free
disk space.

## Local data and updates

Preferences and history are stored in
`~/Library/Application Support/Sweepdeck/state.json`. History can contain file paths.
If you check for updates, Sweepdeck contacts its signed GitHub release feed and sends
no system profile.

## More

- [Compatibility and verification](COMPATIBILITY.md)
- [Release process](Docs/RELEASING.md)
- [Architecture](ARCHITECTURE.md)
- [Safety and limitations](SAFETY.md)
- [Contributing](CONTRIBUTING.md)
- [Roadmap](Docs/ROADMAP.md)
- [License](LICENSE)
