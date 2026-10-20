# Validation record

Recorded on 2026-10-20, macOS 26.6.2, arm64, Swift 6.2. The local host has
Command Line Tools but no active full Xcode installation. GitHub Actions run
[#13](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39477118776) passed
the tests and release build with Swift 6.2 on `macos-15` and Swift 6.4.1 on
`macos-26`. Interactive UI behavior was not checked on either CI runner.

## Automated checks

- `bash scripts/swift.sh test` passed: 33 Swift Testing tests in two suites. Coverage
  includes scanning, cancellation and result limits; path/symlink/repository and
  metadata safety; overlapping-root deduplication; cleanup preview, stale-item
  refusal, fake Trash and partial results; full preference/history round-trip
  and threshold bounds; persistence boundaries; metrics; and 20,000-entry
  candidate indexing. A scanner regression test also verifies that ancestry is
  resolved once per directory and that each file retains the same full identity
  snapshot as a fresh filesystem walk. Progress tests cover the final scan
  snapshot plus cleanup success, stale-item rejection, partial failure,
  cancellation and batched/final counts. Six CandidateMatcher tests cover
  case-insensitive path/category filtering, all sort modes and tie ordering, and
  verify that progress callbacks run off the main thread and reach the final
  candidate count.
- `bash scripts/build-app.sh` passed. It built the release binary, ad-hoc signed and
  strictly verified the app bundle in temporary storage, and produced
  `dist/Sweepdeck-macOS.zip`.
- GitHub Actions run [#13](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39477118776)
  passed the 33-test suite and release app build on the `macos-15` runner with
  Swift 6.2 and on the `macos-26` runner with Swift 6.4.1. The baseline lane also
  uploaded the app archive. These checks verify automated compatibility at the
  deployment floor and with the latest stable toolchain, not interactive UI
  behavior on either macOS version.
- Standalone CLI smokes used generated fixtures only, but could not verify Trash
  without the app's folder-picker flow: direct `FileManager.trashItem` returned
  Cocoa error 513 / OSStatus -5000 (`afpAccessDenied`), and `MacTrashService`
  returned Cocoa error 512 from a temp location. The same app path passed after
  the test app authorized a disposable root through `NSOpenPanel` (see UI checks).
  An attempted fixture root under the Documents file-provider location was
  rejected as cloud-managed. Those CLI fixtures were removed; no user files were
  scanned or moved by the CLI. Unit tests also exercise an injected fixture Trash
  adapter.

## UI checks

The test app used its own temporary preferences and 3,000 generated `.dmg` files
under `/private/tmp/SweepdeckUIFixture`.

- Scan: 3,000 entries in 1.5 seconds, with 0 skipped and 0 issues.
- Before paging, expanding the 3,000-row cleanup group stalled for more than
  18 seconds while SwiftUI laid out thousands of rows at once.
- After paging, group expansion returned in 2.7 seconds. The first page exposed
  100 candidates; loading the next page returned in 3.7 seconds. Selecting and
  clearing all 3,000 candidates each returned in about 1.2 seconds.
- Dashboard, Smart Cleanup, Disk Explorer, System Health and Operation Results
  were visually inspected. Cleanup also exercised search, category filtering,
  sorting, details, group selection, paging and dry-run preview.
- The later async CandidateMatcher change was not visually rechecked. Its search,
  category and sort behavior is covered by the new core tests, including a check
  that progress callbacks run off the main thread; this is executor-isolation
  evidence, not a runtime screenshot or end-to-end latency measurement. While it
  recomputes, the view now shows progress and hides rows from the previous search.
- Progress UI shows the inspected count while scanning, matching count while
  filtering, and a determinate cleanup indicator over ready items. Debug and
  release builds compile this UI, but the updated matching indicator was not
  visually rechecked:
  CUA returned “Sky Computer Use native pipe closed before response” when
  selecting the running app. This feature therefore has build and callback-test
  evidence, but no fresh runtime screenshot.
- End-to-end Trash flow passed with a separate 28-byte generated `.dmg` fixture:
  authorize its single-file root with `NSOpenPanel`, scan, select, review the
  dry-run, acknowledge and move to Trash. The app reported one successful move,
  its isolated history recorded a successful move into the current user's Trash,
  and the source fixture folder was empty afterward. The synthetic file remains
  recoverable in Trash; Trash was not emptied.
- A separate read-only live scan of the actual Downloads folder inspected 14,947
  entries in 19.4 seconds, with 44 skipped and 39 issues. The review showed
  13,483 older-download candidates; none were selected or moved. Recent installers
  did not meet the default 60-day threshold.
- Settings was not visually verified. Both the staged release app and a fresh
  copy with a distinct bundle ID rendered their Dashboards and remained listed
  as running, but switching to Settings closed the computer-use pipe. The bridge
  worked with Finder in the same session;
  macOS diagnostic reports from prior attempts identify an `EXC_BREAKPOINT` in
  `SkyComputerUseService`. This points to an automation-service failure, but does
  not prove whether Settings itself works or fails. Its code was reviewed, and
  its preference persistence and bounds are covered by unit tests; visual checks
  of Settings controls and flows remain outstanding.

The UI checks were manual, fixture-based checks rather than XCTest UI tests. The
read-only Downloads scan is the only personal-folder scan recorded here; it did
not select or move any of its files. One generated fixture was moved to Trash for
the end-to-end test, and Trash was not emptied.

## Adversarial review

- The supplied hang stack and the 3,000-file reproduction point to SwiftUI/AppKit
  row layout in expanded Cleanup groups. Scanning itself took 1.5 seconds. Paging
  bounds instantiated rows to 100 per group; replacing Swift with Rust would not
  remove the native view-layout work that caused this hang.
- Scan and issue caps bound the core report, and the UI now bounds row creation.
  A debug-build probe of 25,000 synthetic records previously measured 39 ms for a
  name filter and 7–15 ms for each sort mode; a broad filter plus name sort was
  about 51 ms before SwiftUI updates. Although that data pass was relatively
  short, the supplied stack sample implicated main-thread SwiftUI layout. The
  filter/category/sort pass now runs in nonisolated async SweepdeckCore work,
  and its progress callback is verified to run off the main thread. This proves
  executor isolation, not end-to-end responsiveness or faster total throughput.
  A Swift sort already
  in progress cannot be interrupted, but its result is discarded if the search
  task was cancelled; the bounded 25,000-record scan cap limits that work.
- A separate debug SwiftPM scan fixture with 3,000 old `.dmg` files in one
  directory took 5.38 seconds before and 1.30 seconds after caching validated
  directory ancestry (about 4.1× faster). Fixture creation was outside the timed
  interval. This is a single-host library measurement, not an end-to-end UI
  benchmark; automated coverage checks ancestry-call counts and exact snapshots
  rather than enforcing a flaky time threshold.
- A Rust core is technically possible behind a Swift FFI, but this scan is
  dominated by filesystem metadata and Apple URL resource checks. The measured
  improvement removes repeated ancestry I/O while retaining those native checks.
  `rustc` and `cargo` are not installed on this host, so no equivalent Rust
  benchmark was run; the current evidence does not justify adding a second
  toolchain and FFI layer.
- Cleanup still revalidates the selected root, ancestry, file identity/metadata,
  exclusions and rule before Trash, including inside coordinated access. The
  remaining non-atomic pathname race against an uncoordinated local process is
  documented in `SAFETY.md`.
- Cleanup progress counts ready candidates that have reached an outcome, not just
  successful Trash moves. Updates are sent on the first, every 16th, and final
  item; failures and cancellation still advance the count without increasing
  main-thread updates for every file.
- Adversarial review confirmed the ancestry cache is per-root and per-scan, uses
  a full walk when a parent snapshot is unavailable, and leaves preview/execute
  revalidation unchanged. Because a scan is not an atomic filesystem snapshot,
  concurrent tree mutations can make scan results stale; the preview and final
  operation reject changed identities or newly protected ancestry. No scan
  result is persisted across operations.
- Adversarial review caught and fixed a stale-results window: a changed query
  previously left the prior rows selectable until async matching completed. The
  view now shows an updating state until results match the current search key.
  This UI state has compile coverage but still needs a fresh visual check.
- No additional safety defect was established in this pass. The matcher change
  leaves scanning, selection, preview, and cleanup validation boundaries intact.
  Settings controls and the remaining Settings flows still need a visual check
  because the automation service fails when entering that screen; the project has
  no XCTest UI-test runtime here. The latest matcher UI also lacks a fresh visual
  check for the same computer-use bridge failure.
