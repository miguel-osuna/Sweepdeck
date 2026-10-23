# Sweepdeck MVP design

## Intent and scope
Build a free, local, native Mac utility for explicitly authorized folder scans,
individual candidate review, and confirmed Finder-style Trash operations.
Never run cleanup against personal data during development. Original code only.
No backend, telemetry, privileged helper, auto indexing, or permanent deletion.
The public GitHub release feed is used only for opt-in update checks; no system
profile is sent.

## Environment and approach
Observed: Apple Silicon, macOS 26.6.2, Swift 6.2, SDK 26.0, Command Line Tools,
no active full Xcode or signing identity. Use SwiftPM, SwiftUI/AppKit and an
ad-hoc signed app bundle. Minimum macOS 15; only the observed host is tested.
Alternative: an Xcode project adds IDE/UI-test convenience but requires tools
absent here. Sandbox + security-scoped bookmarks would improve OS confinement
but add persistent access complexity. Choose an unsandboxed local app with
explicit in-app root authorization and strict safety checks; TCC still applies.
This is an application policy boundary, not an OS security boundary.

## Components
- SweepdeckCore: immutable models, rule registry, filesystem adapter, safety
  policy, scanner, cleanup executor, preferences/history persistence, metrics.
- Sweepdeck: main-actor presentation, five sidebar sections and native controls.
- Scanner and executor actors: serial bounded work, cancellation, progress,
  capped result retention and errors. No content reads for ordinary scanning.
- Filesystem protocol: real metadata validation, injected Trash adapter for tests.

## Safety contract
Empty initial selection. Only regular single-link local files are candidates.
No recursive directory removal. Root authorization records device/inode and
path. Recheck every path ancestor, current identity/metadata, policy, exclusions,
volume, rule and plan age before mutation. Reject symlinks, hidden files,
packages, repositories/worktrees, protected directories and cloud-managed data.
Exclusions use component boundaries. File age and size imply Review Required,
never proof of disposability. No automatic low-risk selection in this release.
Use FileManager.trashItem under NSFileCoordinator after validation. No fallback
to unlink/removeItem. Report partial success. Moving to Trash is not recovered
space. Foundation path APIs cannot eliminate adversarial uncoordinated rename
races: document that limitation, reject observed changes, and avoid claiming a
security boundary against a malicious concurrent local process.

## MVP interface
Dashboard: capacity, scan summary, recommendation cards, choose folder and scan.
Cleanup: grouped candidates, search/sort, per-file/category selection, details,
exclude/reveal, dry-run sheet with explicit Trash confirmation.
Explorer: drill-down into the scan's visible eligible files with aggregate sizes;
clearly partial, bounded scan data, not a full volume accounting tool.
Health: disk, RAM and swap, CPU samples while visible; no fake health score.
Settings: authorized roots, exclusions, rules/thresholds, appearance, history,
redacted diagnostic export and version. No inactive placeholder controls.

## Deferred
Duplicates, recursive directory cleanup, app uninstaller, managed developer
cache mutation, external volumes, process controls, treemap and menu-bar mode.

## Verification
Temporary fixtures only, fake Trash backend for unit tests, dry-run integration,
release build, bundle validation and native launch. Full Xcode UI tests unavailable
unless Xcode is installed. No system configuration or permission changes.
