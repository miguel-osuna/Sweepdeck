# Changelog

## Unreleased

Initial native MVP: authorized-folder scanning, review-only cleanup rules, per-file
selection, exclusions, dry-run preview and confirmed Trash; partial scan explorer,
visible-only system metrics, local preferences/history and fixture tests.

Large cleanup groups now render in pages of 100 while keeping search, sorting,
details, per-file selection and group-wide selection available. Explorer candidate
lookups use a path index rather than repeatedly scanning the full candidate list.
Candidate filtering and sorting now run away from the UI actor with batched progress.

The first public release remains reserved for 0.1.0 after product, regression,
distribution and compatibility checks are complete.
