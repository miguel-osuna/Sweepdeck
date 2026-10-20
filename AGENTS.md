# Sweepdeck engineering rules

- Read DESIGN.md, SAFETY.md and ARCHITECTURE.md before changing cleanup behavior.
- Native SwiftUI/AppKit, macOS 15+, Swift 6 concurrency, Apple frameworks only.
- No permanent deletion, privileged helpers, telemetry or background indexing.
- Never scan or clean personal/system files while developing or testing.
- Root access must be explicitly chosen. Preserve empty selection and final preview.
- Revalidate identity, ancestry, exclusions, ownership, local volume and rule before
  Trash. Never weaken protections to satisfy a test or increase reclaimed bytes.
- Filesystem logic lives in SweepdeckCore, UI state on the main actor. Tests use
  temporary fixtures and injected Trash; no production test-only cleanup methods.
- Keep all shell/managed developer integrations read-only until separately approved.
- Build: `bash scripts/build-app.sh`; tests: `bash scripts/swift.sh test`.
- The wrapper's toolchain workarounds are workspace-local. Never modify Xcode/CLT,
  macOS settings, TCC, SIP or signing identities to make the app build.
- Update compatibility evidence honestly; deployment target is not test evidence.
- Preserve unrelated user work. No public publishing or external messaging implied.
