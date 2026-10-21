# Release process

Releases are calculated from Conventional Commit messages and are created only from
`main`. Examples:

- `feat: add an export option` requests a minor release.
- `fix: preserve folder selection after refresh` requests a patch release.
- `feat!: change the saved-state format` requests a major release.

The release workflow is manual. Its `publish` input defaults to false, the repository
must have `RELEASE_READY=true`, and all supported macOS/Swift CI lanes must pass.
The `release` GitHub Environment must have at least one required reviewer. Before it
runs CI or builds a candidate, the gate checks that reviewer protection exists and
fails closed if it does not. Configure the environment under repository Settings >
Environments. The workflow then builds a versioned candidate for manual QA and keeps
it as a seven-day Actions artifact. The publish job waits for environment approval
before creating the tag and GitHub Release. If there is no release-worthy commit, it
exits without publishing.

The first publish run creates the `v0.0.0` analysis baseline at the repository's single
root commit, and verifies any existing baseline tag still points there. The workflow
refuses to publish if semantic-release does not propose exactly `0.1.0` as the first
release. Subsequent versions follow Conventional Commit rules. The release tool does
not publish an npm package.

## Distribution status

The release workflow builds `Sweepdeck-<version>-macOS.zip` and a neighboring
`.sha256` file from the version proposed by semantic-release. It verifies the checksum,
retains both files in the seven-day candidate artifact, then reuses those exact files
after the protected publish job creates the tag and GitHub Release. The app ZIP is a
minimal app bundle; it does not contain a separate installer or support files.

Before publication, a separate Homebrew candidate job downloads those exact files and
runs the cask through Homebrew audit and style, installs and uninstalls it on a
disposable `macos-26` Apple Silicon runner, checks the installed
bundle and Homebrew quarantine, runs `spctl`, and attempts a first launch with
`SWEEPDECK_STATE_DIR` pointed at temporary state. The test never removes quarantine,
disables Gatekeeper, scans personal folders, or adds cask lifecycle scripts. A failed
Gatekeeper or launch check fails the candidate job and prevents the protected publish
job from running. The public tap's pull-request workflow will repeat audit, style,
install, uninstall and first-launch checks against the actual versioned GitHub Release
URL on `macos-26` before a cask update can merge.

The first disposable candidate check ran on 2026-10-21 in
[Actions run 39569344355](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39569344355).
Homebrew strict audit, style, install, installed-bundle inspection, and uninstall
passed for the release-shaped 0.1.0 candidate. The check confirmed the ARM64 Mach-O
executable, the expected app bundle and version, and a Homebrew quarantine attribute.
`spctl --assess --type execute --verbose=4` rejected the app (exit status 3).
Launch Services did not return within 15 seconds and no Sweepdeck process appeared.
This run used the candidate ZIP through a temporary local tap; it did not publish a
GitHub Release asset or a public cask. The candidate is not release-ready. Developer
ID signing and notarization are not being added for this release attempt.

A repeat in [Actions run 39570883868](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39570883868)
reproduced the same result after adding bounded launch diagnostics: Homebrew
audit/style/install/uninstall passed, quarantine remained present, `spctl` rejected
the app with exit status 3, Launch Services timed out, and no app process appeared.
A third repeat in [Actions run 39571447748](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39571447748)
also passed Homebrew audit, style, install, bundle inspection, and uninstall, then
reproduced Gatekeeper rejection (exit status 3), the 15-second Launch Services timeout,
and no app process.
A fourth check after merging the main-branch test-runner fix, in [Actions run 39608770720](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39608770720),
also passed audit, style, install, bundle inspection, and uninstall before reproducing
the same quarantine-preserving Gatekeeper rejection and failed first launch.
A fifth check after rebasing onto the appearance fix on `main`, in [Actions run 39624090614](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39624090614),
again passed audit, style, install, bundle inspection, and uninstall, then reproduced
Gatekeeper rejection (exit status 3), the 15-second Launch Services timeout, and no
app process.

The cask belongs in the owner-managed public repository
[`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap), at
`Casks/sweepdeck.rb`. The primary command is
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew trusts only that fully
qualified cask for this command. To use the short command, users must run
`brew tap miguel-osuna/tap`, then
`brew trust --cask miguel-osuna/tap/sweepdeck`, then
`brew install --cask sweepdeck`. A fresh Homebrew setup cannot use the short command
without those steps or inclusion in an official tap.

The cask installs only `Sweepdeck.app`; it has no `zap` stanza or cleanup scripts, so
uninstall leaves preferences and history intact. Cask version updates are manual and
reviewed: after each app release, verify the published `.sha256`, update the cask's
version and checksum while keeping its versioned release URL pattern, and open a PR in
`homebrew-tap`. The tap's disposable macOS CI must pass `brew audit --cask --strict`,
`brew style --cask`, install, first launch under quarantine, and uninstall before that
PR is merged. No cross-repository Actions token is required for this manual process.

Neither App Store submission nor notarization is required by the cask format. They
remain Gatekeeper compatibility decisions. The current app build is ad-hoc signed,
and five quarantined candidates were rejected by Gatekeeper on a disposable Apple
Silicon runner. Do not mark the release ready or publish the cask unless a future
supported build passes the same checks. Never remove quarantine or bypass macOS
security controls.

At the 2026-10-21 eligibility check, the canonical Sweepdeck GitHub repository had 0
stars, forks, and watchers and was one day old. Homebrew's normal thresholds are 30
forks or watchers or 75 stars, increased to 90 forks or watchers or 225 stars for a
self-submission; repositories under 30 days old are normally ineligible. No
official-cask PR is being prepared; this does not prevent distribution through the
owner-managed tap.

## Dependencies and security

Release tooling is pinned in `package-lock.json` and updated weekly by Dependabot.
The CI audit currently reports eight affected package entries, all tracing to the same
unpatched `braces@3.0.3` issue: [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
It is a dev-only release-tool dependency and is not included in the app. npm's suggested
remediation downgrades semantic-release across a major-version boundary, so CI reports the
finding without applying that downgrade. The release workflow also runs manually on `main`
with a fixed branch pattern. That limits exposure; it does not clear the advisory. Reassess
when upstream ships a fix or semantic-release removes the affected dependency.
