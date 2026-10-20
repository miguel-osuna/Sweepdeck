# Sweepdeck

A native, local macOS utility for understanding storage and reviewing files before
moving them to Trash. Free, original MIT-licensed code. No subscriptions, accounts,
telemetry, network services or background indexing.

## Build and run

Requires Apple Silicon macOS 15+, Swift 6.2 and the macOS SDK. Xcode or matching
Command Line Tools are sufficient. No package downloads are required.

```sh
bash scripts/swift.sh test
bash scripts/build-app.sh
open dist/Sweepdeck.app
```

The build creates a locally ad-hoc signed app. No developer identity or provisioning
profile is needed. This is not a notarized public distribution build.

On a healthy Xcode installation, `swift test` and `swift build -c release` also work.
The wrapper keeps caches inside `.build` and handles two detected remnants of
incomplete Command Line Tools upgrades without modifying installed tools. See
[compatibility](COMPATIBILITY.md). Swift 6 language mode is selected by the package's
Swift tools version. The wrapper disables SwiftPM's manifest sandbox for this
dependency-free local package; this does not change macOS settings or app permissions.

## First use

1. Choose a specific folder using **Choose Folder**. Nothing scans at startup.
2. Select **Scan Mac**. Only authorized folders are scanned.
3. Open **Smart Cleanup**, expand a category, inspect individual files, and select
   only the files you no longer need. Every current category requires review.
4. Choose **Preview Cleanup** for a dry run. Review all paths and rejected items.
5. Acknowledge the review and explicitly choose **Move Files to Trash**.

Use Finder's Trash to restore files. Sweepdeck never permanently deletes files or
empties Trash. Moving files to Trash usually does not immediately free space.

## Implemented MVP

- Capacity dashboard with file-size estimates and recommendation cards.
- Cancellable, serial metadata scans of explicitly chosen local internal folders.
- Old regular-file DMG/PKG installers, old Downloads files, old `.log` files,
  and large files with configurable thresholds. Age and size are discovery signals.
- Empty initial selection, category and per-file selection, filtering/sorting,
  details, Finder integration, file/folder exclusions and rule toggles.
- Dry-run preview, five-minute plan expiry, identity/policy revalidation and
  confirmed Trash operations with per-file outcomes and cancellation.
- Partial, size-sorted folder explorer using the scan's eligible files.
- CPU, RAM estimate, swap, storage and thermal metrics while Health is visible.
  Activity Monitor opens for memory pressure and process details.
- Local preferences, bounded operation history, appearance and redacted diagnostics.

## Deliberate limits

Individual regular files only. No directory deletion, app uninstalling, duplicates,
developer-cache mutation, external/network volume scanning or process termination.
Repositories/worktrees, hidden files, Library data, known secrets/databases,
packages, symlinks, hard links, special flags and cloud-managed files are excluded.
Some ordinary files will be conservatively excluded. See [safety](SAFETY.md).

Scans stop after 25,000 visited entries and retain up to 100 issue details. Explorer
totals exclude protected/inaccessible files and are not full-volume accounting.
Folder/rule/exclusion changes invalidate existing results; rerun the scan.

## Local data and privacy

Preferences/history live in `~/Library/Application Support/Sweepdeck/state.json`.
History can contain file paths and retains at most 50 operations / 1,000 item
results. Diagnostics export contains counts and OS/app versions, not paths or
file contents. No data is sent anywhere.

For isolated validation, set `SWEEPDECK_STATE_DIR` to a temporary state directory
when launching the executable. This only redirects preferences/history; it does
not add folders, scan, or authorize cleanup.

## Maintenance

- [Architecture](ARCHITECTURE.md)
- [Safety and limitations](SAFETY.md)
- [Compatibility and verification](COMPATIBILITY.md)
- [Contributing](CONTRIBUTING.md)
- [Roadmap](Docs/ROADMAP.md)
- [License](LICENSE)
