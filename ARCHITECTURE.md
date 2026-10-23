# Architecture

SwiftPM builds `SweepdeckCore`, a UI-independent Swift 6 library, and `Sweepdeck`,
a SwiftUI/AppKit executable. The packaging script installs the binary and Info.plist
into a standard app bundle and signs it ad hoc for local use.

## Data flow

`NSOpenPanel → LocalFileSystem.authorize → Preferences → Scanner actor → ScanReport`

`ScanReport → Selection → CleanupExecutor.preview → immutable CleanupPlan → explicit
UI confirmation → CleanupExecutor.execute → per-item OperationRecord → JSONStore`

`AppModel` owns presentation state on the main actor. `UpdateManager` wraps Sparkle's
standard updater and exposes opt-in update checks. A check may run during a scan; the
updater prevents new cleanup work while it downloads. Sparkle verifies the EdDSA-signed
feed and archive before extraction. Its relaunch hook waits for a scan, preview, Trash
operation, or folder panel to finish. Automatic installation is available as an opt-in
setting and starts off; users are advised to keep it off until a quarantined candidate
passes Gatekeeper testing. Scanner/executor actors perform
filesystem work away from the main actor. Progress crosses through sendable values.
One cleanup operation is active at a time. Settings changes invalidate results. Root
and policy snapshots are immutable during operations; the UI disables relevant edits.

## Core boundaries

- Models.swift: value types, bounded settings and empty-by-default selection.
- FileSystem.swift: lstat metadata, root identity, repository ancestry, public URL
  resource capabilities. `FileSystem` is injectable for failures/capability tests.
- Safety.swift: component-aware path rules and deletion-time validation.
- Scanner.swift: serial lazy enumeration, no content reads, 25k visit cap, 100
  issue detail cap, cancellation and progress every 64 visited entries.
- CleanupExecutor.swift: side-effect-free preview, expiring plans and injectable
  `TrashService`. Production adapter only uses coordinated macOS Trash.
- CleanupView sends query/category filtering and sorting to async SweepdeckCore
  work away from the UI actor, reports batched matching progress, discards stale
  task results, and renders fixed 100-row pages. Disk Explorer, cleanup
  confirmation, operation results, and long Settings root/exclusion lists use
  the same bounded page contract. Previous/next navigation preserves access to
  every result without growing the SwiftUI view tree as users browse.
- Persistence.swift: versioned atomic JSON, local restricted file permissions,
  no silent recovery from malformed data, bounded operation history.
- Metrics.swift: public Mach, sysctl, URL volume and ProcessInfo adapters.

## Rule registry

`RuleID` gives each rule a stable identifier, description and symbol.
`RuleRegistry.classify` assigns one deterministic primary rule per file:
installers, logs, old Downloads, then large files. All require review, folder
authorization and macOS 15+. All inherit the same mandatory exclusions, validation
and Trash-only executor. Rule enablement and thresholds are rechecked at execution.
New rules must add safety/discovery fixtures before enabling them.

## Resource and privacy constraints

No filesystem watchers, startup scans, persistent result cache or background agent.
The explorer computes aggregates from bounded scan results, not fresh I/O. The
health task is tied to its view and scene activity and samples every three seconds.
Memory used is explicitly an active+wired+compressed estimate. Exact pressure and
per-process views are delegated to Activity Monitor; no guessed score.

Sparkle 2.10.0 is included as a checksum-pinned binary framework; it is the app's only
third-party runtime dependency. Apple API references and inspiration are tracked in
Docs/REFERENCES.md. Advanced integrations are future modules, not hidden buttons.
