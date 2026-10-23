# Contributing

Use Swift 6.2+ and macOS SDK 26.0 or a compatible toolchain. Open Package.swift in
Xcode if desired; full Xcode is optional for the command-line workflow.

Run `bash scripts/swift.sh test` and `bash scripts/build-app.sh`. Keep concurrency
warnings and compiler diagnostics visible. Sparkle 2.10.0 is the sole third-party
runtime dependency and is fetched from its official binary release with a pinned
checksum. Release tooling uses exact-pinned npm development dependencies.

Use unique temporary fixture directories. Test discovery, protection, root identity,
symlink ancestors, stale metadata, exclusions, selection, cancellation, partial
failures and persisted state. Inject `TrashService`; never point a test at actual
personal or system data. Never add a force-delete fallback to make a test pass.

Manual checks: launch a locally built bundle with an isolated state directory;
authorize a folder containing synthetic old/new installer files; scan, inspect,
select/deselect, exclude, cancel, preview and dismiss. Exercise both appearance
modes, keyboard traversal and narrow window sizes. Real Trash integration must use
disposable fixtures only. Record what was actually tested in COMPATIBILITY.md.

New cleanup modules need reliable discovery evidence, an explicit risk rationale,
permissions/exclusions, cancellation, a validated execution method and tests.
Managed-tool mutation stays disabled until separately implemented and reviewed.
Do not copy GPL or restricted source into this MIT project.

Do not commit private paths, JSON state, certificates, profiles, `.build` or `dist`.
