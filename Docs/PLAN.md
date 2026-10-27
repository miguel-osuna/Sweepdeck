# Implementation status

The latest public release is [0.4.0](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.4.0).
It includes Sparkle updates. Install 0.4.0 manually once when upgrading from 0.3.0 or
earlier; those versions do not contain an updater.

## Done

- The signed HTTPS appcast and 0.4.0 release archive are published. The disposable
  post-release runner installed the update and verified preserved test state.
- Local tests passed for user-approved and automatic installation, relaunch deferral,
  offline feeds, tampered archives, and a quarantined update. Sparkle cleared quarantine
  during installation and relaunched the test app. `spctl` still rejects the ad-hoc
  signature, so this does not establish Gatekeeper approval.

## Pending

- The new PR and release workflow quarantine checks are wired but have not run on a
  disposable macOS runner. They must fail if Gatekeeper blocks the updated app's
  relaunch.
- This worktree enables automatic installation by default after a user opts into
  automatic checks. The published 0.4.0 release still asks before installing.
- The Homebrew tap still installs 0.3.0; the local 0.4.0 cask draft has not been
  published. Keep `auto_updates` absent until the runner checks pass.
- Manual visual comparison of saved preferences/history and the Settings controls is
  incomplete. Automated state checks passed.
- Keep an encrypted offline recovery copy of the signing key outside the repository
  and release environment.

## Next

1. Run the new quarantine checks on a disposable macOS runner and record their results.
2. Refresh the Homebrew cask only after those checks pass.
3. Keep release publication reviewer-gated and retain the signed-feed/manual-download
   recovery paths.

See [COMPATIBILITY.md](../COMPATIBILITY.md) for validation evidence and
[RELEASING.md](RELEASING.md) for the release procedure.
