# Sweepdeck implementation plan

Goal: deliver the MVP in DESIGN.md, executing locally and autonomously as requested.
Architecture: Swift 6 core library plus SwiftUI executable and bundle script.
Spec: DESIGN.md. Minimum macOS 15. Apple frameworks with the pinned Sparkle updater.

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

## In-app update rollout

The updater implementation uses Sparkle 2.10.0, a checksum-pinned framework,
EdDSA-signed appcasts and archives, and a stable GitHub Pages feed. The app asks before
installing an update and waits for scans, previews, Trash operations, and folder panels
to finish before relaunching. Automatic update checks remain opt-in, and automatic
installation is disallowed in production builds until a quarantined candidate passes
Gatekeeper testing. The Settings control remains visible but disabled with an
explanation. Once validation passes, the separate installation option can be allowed
and will start off.

1. **Foundation and automatic local path — implemented; manual version and scan
   deferral confirmed, state visual check pending.** Bundle Sparkle, expose manual checks,
   preserve local app state, and defer relaunch during protected work. The isolated
   automatic two-version localhost update
   passed; it verified the seeded preference/history file, launch marker, updated
   version, signature, and unchanged installed app. The exact 0.4.0 candidate also
   passed the automatic localhost update with a generated ephemeral signing key.
   Deferral tests now cover the mapping from scanning, preview validation, Trash, and
   folder-panel states to relaunch protection, as well as the deferral state machine.
   Automatic 0.3.0-to-0.4.0 localhost updates passed with
   both the production Keychain key and an ephemeral key; the 0.4.0 candidate also passed
   with an ephemeral key. The relaunched dashboard visibly reports 0.4.0, and the user
   confirmed that the post-update Settings footer reports 0.4.0. The manual visual
   before/after preferences and history check remains unverified; the automated
   state-file checks passed. The latest visible manual run fetched its localhost feed but
   no update was initiated before the test timed out at 0.3.0; the native UI bridge could
   not attach. A live scan-deferral run used the generated empty-directory
   fixture: Sparkle offered 0.4.0 with automatic installation unchecked, stayed at
   “Ready to Install” after installation was requested during an active scan, then
   relaunched after the scan result was saved. The updated bundle signature, 0.4.0
   launch marker, seeded preferences/history, and completed scan state were verified.
   The offline-feed UI showed Sparkle's retrieval-error dialog; the harness confirmed the
   app stayed on 0.3.0. The tampered-feed UI offered 0.4.0, then rejected its modified
   archive as improperly signed; the harness confirmed the app stayed on 0.3.0. Both
   visible failure tests passed. A focused Settings-controls visual check remains
   pending: the local UI bridge closed during the latest attempt to inspect Settings.
   Production automatic installation remains disabled until the quarantine gate passes;
   isolated tests explicitly enable it only in their temporary app bundles.
2. **Signed release feed — configured.** Keep `SPARKLE_EDDSA_PRIVATE_KEY` in the
   reviewer-protected `release` environment. Generate and verify the appcast from the
   exact tested candidate; publish and verify release assets, then deploy only
   `appcast.xml` to the workflow-configured Pages site. Confirm the public feed digest
   matches the signed artifact. Before publication, the workflow also downloads the
   exact candidate ZIP on a disposable macOS runner and completes the localhost
   install-and-relaunch harness with an ephemeral test key. That exact-candidate release
   gate has not yet run on GitHub. Pull-request CI now separately runs the automatic
   localhost install-and-relaunch test with an ephemeral key; the PR checks passed. The
   public appcast currently returns 404 until the first Sparkle-enabled release deploys
   the signed feed, so pre-release production-feed checks show Sparkle's retrieval error.
   A separate post-deploy smoke downloads the published
   appcast and release ZIP, installs it on a disposable runner, and validates the new
   version and preserved state. That job is configured but cannot run until the first
   Sparkle-enabled release publishes the feed.
3. **Quarantined update gate — pending.** On a disposable supported macOS runner, test
   Gatekeeper acceptance, update signature rejection, state preservation, user-approved
   install, and relaunch deferral while scanning an explicitly authorized temporary
   fixture. The current ad-hoc signed build cannot establish this evidence.
4. **Broader rollout — blocked on step 3.** Keep automatic installation opt-in and off
   by default, and keep `auto_updates true` out of the Homebrew cask until that runner
   test passes. If verification fails, retain user-approved in-app installation and
   manual downloads as the recovery path.

The rollback checkpoint is the signed feed: do not deploy it until the candidate and
its release assets pass. If a deployed feed is wrong, publish a higher-version corrected
release with the same key and keep manual downloads available for recovery. Never replace
the signing key without coordinating a new public key in the app.
