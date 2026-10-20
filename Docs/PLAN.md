# Sweepdeck implementation plan

Goal: deliver the MVP in DESIGN.md, executing locally and autonomously as requested.
Architecture: Swift 6 core library plus SwiftUI executable and bundle script.
Spec: DESIGN.md. Minimum macOS 15. Apple frameworks only.

## Review focus
Ancestor rename/symlink replacement; nested repositories; stale same-size files;
root reauthorization and revoked exclusions; cancellation/partial mutation.

## Milestones
- [ ] Safety: write fixture tests, observe failure, implement path/identity policy.
  Files: Sources/SweepdeckCore/{Models,FileSystem,Safety}.swift and safety tests.
  Interface: authorize(URL), inspect(URL), validate(candidate, roots, settings).
- [ ] Scan and cleanup: test real discovery and injected Trash failures, implement
  Scanner.scan and CleanupExecutor.preview/execute with immutable plans.
  Include missing/changed targets, cancellation, exclusions and result limits.
- [ ] Persistence and metrics: test preferences/history round trips and failures;
  implement local JSON store and public Mach/sysctl metric adapters.
- [ ] UI: dashboard, grouped review, confirmation, scan explorer, visible-only
  health monitoring, settings and history. Manual fixture-based UI verification.
- [ ] Ship: release bundle, ad-hoc signing, CI, docs, safety review and launch check.

Verification command: swift test; release bundle: ./scripts/build-app.sh.
No personal-folder scanning or cleanup is part of automated validation.
