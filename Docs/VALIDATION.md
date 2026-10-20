# Validation record

Recorded on 2026-10-20, macOS 26.6.2, arm64, Swift 6.2. The local host has
Command Line Tools but no active full Xcode installation. GitHub Actions run
[#70](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39506723318) passed
41 tests, the 80% `SweepdeckCore` coverage floor and the release build with Swift
6.2 on `macos-15` and Swift 6.4.1 on `macos-26`. Interactive UI behavior was not
checked on either CI runner.

## Automated checks

- `bash scripts/swift.sh test --enable-code-coverage` passed locally: 41 Swift Testing tests in four suites. Coverage
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
  candidate count. Disk Explorer tests cover root/folder aggregation, nested files,
  extension/size/age filters, authorized-root boundaries, and batched progress off
  the main thread over 3,000 entries. Four `ResultPageTests` cover empty and
  partial pages, invalid indexes and dimensions, safe very-large ranges, and
  lossless traversal of 25,000 rows while limiting each page to 100.
- The current coverage-instrumented run measured 578 of 676 executable
  `SweepdeckCore` source lines covered (85.5%). `DiskExplorerMatcher.swift` has
  97.1% line coverage. The SwiftUI app target is not included in the SwiftPM test
  coverage report. CI enforces an 80% `SweepdeckCore` executable-line floor on
  both macOS toolchains.
- `bash scripts/build-app.sh` passed. It built the release binary, ad-hoc signed and
  strictly verified the app bundle in temporary storage, and produced
  `dist/Sweepdeck-macOS.zip`.
- GitHub Actions run [#70](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39506723318)
  passed the 41-test suite, 80% `SweepdeckCore` line-coverage floor and release
  build on the `macos-15` runner with Swift 6.2 and on the `macos-26` runner with
  Swift 6.4.1. The baseline lane also uploaded the app archive. These checks
  verify automated compatibility at the deployment floor and with the latest
  stable toolchain, not interactive UI behavior on either macOS version.
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
- With the former cumulative “Show next” control, group expansion returned in
  2.7 seconds and exposed 100 candidates initially; adding another 100-row
  batch took 3.7 seconds. Repeatedly adding batches could still grow the rendered
  view to thousands of rows. Selecting and clearing all 3,000 candidates each
  returned in about 1.2 seconds.
- The current implementation replaces cumulative growth with fixed 100-row
  previous/next pages in Cleanup, Disk Explorer, cleanup confirmation, operation
  results, and long Settings folder/exclusion lists. `ResultPageTests` verifies
  25,000 results can be traversed without gaps or duplicates and each visible
  range stays within the page size. The SwiftUI layout itself has not been
  remeasured since these changes.
- Dashboard, Smart Cleanup, Disk Explorer, System Health and Operation Results
  were visually inspected before the latest asynchronous Explorer update. Cleanup
  also exercised search, category filtering, sorting, details, group selection,
  paging and dry-run preview. The updated Explorer progress and no-match states
  still need a fresh visual check. The computer-use runner could not start because
  its configured executable failed to resolve: `Unable to determine Orca.app path
  from symlink: /usr/local/bin/orca`. The computer-use skill prohibits falling
  through to another executable, so no fresh screenshot or visual claim is recorded.
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
- A user-supplied System Light screenshot with no modal showed the Settings
  detail pane dark while its sidebar remained light. The detail content now fills
  its column with SwiftUI's semantic background so it follows the selected
  appearance. The SwiftPM suite and release build compile this change, but there
  is no UI snapshot test target or working screenshot automation in this setup;
  the rendered fix still needs a native visual check in System Light and Dark.

The UI checks were manual, fixture-based checks rather than XCTest UI tests. The
read-only Downloads scan is the only personal-folder scan recorded here; it did
not select or move any of its files. One generated fixture was moved to Trash for
the end-to-end test, and Trash was not emptied.

## Adversarial review

- The supplied hang stack and the 3,000-file reproduction point to SwiftUI/AppKit
  row layout in expanded Cleanup groups. Scanning itself took 1.5 seconds. The
  old “Show next” control increased the number of simultaneously rendered rows
  in 100-row increments; it did not impose a fixed cap. Cleanup and Disk Explorer
  now use fixed windows of 100 rows. Core tests prove the page contract, but a
  fresh native layout measurement remains outstanding. Replacing Swift with Rust
  would not remove the native view-layout work implicated by the trace.
- Scan and issue caps bound the core report, and high-volume UI result and
  preference lists now use 100-row windows. Operation history is already capped
  at 50 records.
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
- Disk Explorer aggregation previously filtered, grouped and sorted the full scan
  synchronously while SwiftUI evaluated the view. It now runs in nonisolated async
  core work, checks cancellation, and shows progress while hiding results for old
  filters. Tests verify aggregation and executor isolation, not end-to-end UI
  latency; the changed states still need a visual check.
- A separate debug SwiftPM scan fixture with 3,000 old `.dmg` files in one
  directory took 5.38 seconds before and 1.30 seconds after caching validated
  directory ancestry (about 4.1× faster). Fixture creation was outside the timed
  interval. This is a single-host library measurement, not an end-to-end UI
  benchmark; automated coverage checks ancestry-call counts and exact snapshots
  rather than enforcing a flaky time threshold.
- A descriptor-based Rust enumeration prototype was compared with current HEAD
  using the same temporary 3,000-file fixture on this Mac, with three sequential
  release scans per implementation against that already-created fixture.
  The Swift median was 0.890 seconds
  (0.867/0.890/0.942); the Rust-backed median was 1.423 seconds
  (1.382/1.423/1.424). This three-run, one-host experiment is not a general
  performance claim, but it shows the prototype made this scan about 60% slower.
  The prototype crossed the FFI and created a Swift URL for each entry; these are
  plausible sources of overhead, but this trial did not profile the difference.
  It used the latest stable [Rust 1.99.1](https://blog.rust-lang.org/2026/10/15/Rust-1.99.1/)
  and [libc 0.2.191](https://docs.rs/libc/0.2.191/libc/). The prototype was
  discarded; the production scanner remains Swift, where the measured ancestry
  cache and native resource checks already improve scan performance without a
  second toolchain.
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
- The adversarial list review found unbounded Settings root and custom-exclusion
  rows in addition to the large scan-result lists; those views now use the shared
  100-row page contract. No additional safety defect was established. The matcher
  and paging changes leave scanning, selection, preview, and cleanup validation
  boundaries intact.
  Settings controls and the remaining Settings flows still need a visual check
  because the automation service fails when entering that screen; the project has
  no XCTest UI-test runtime here. The latest matcher UI also lacks a fresh visual
  check for the same computer-use bridge failure.
