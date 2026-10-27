# Changelog

## Unreleased

Enabled automatic installation by default after a user opts into automatic update
checks. Users can turn automatic installation off in Settings. Settings warns that
Gatekeeper may block the ad-hoc signed app after an update and provides a manual
download fallback.

## 0.4.0

Added Sparkle in-app updates with a signed HTTPS appcast and versioned GitHub Release
archives. Users can check manually and opt into periodic checks; installing detected
updates requires approval. Relaunch waits for scans, previews, Trash operations, and
folder panels to finish. Automatic installation remains disabled until quarantined
Gatekeeper update testing passes.

Version 0.3.0 and earlier do not contain the updater and must install 0.4.0 manually
once. The public appcast and disposable published-feed update check are live.

## Earlier releases

Initial native MVP: authorized-folder scanning, review-only cleanup rules, per-file
selection, exclusions, dry-run preview and confirmed Trash; partial scan explorer,
visible-only system metrics, local preferences/history and fixture tests.

Large cleanup groups now render in pages of 100 while keeping search, sorting,
details, per-file selection and group-wide selection available. Explorer candidate
lookups use a path index rather than repeatedly scanning the full candidate list.
Candidate filtering and sorting now run away from the UI actor with batched progress.
