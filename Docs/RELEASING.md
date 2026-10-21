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
after the protected publish job creates the tag and GitHub Release. Asset attachment
uploads only missing files and verifies each remote SHA-256, so a retry can finish a
partial upload without replacing a mismatched asset. The app ZIP is a minimal app bundle;
it does not contain a separate installer or support files.

Before publication, a separate Homebrew candidate job downloads those exact files and
runs the cask through Homebrew audit and style, installs and uninstalls it on a
disposable `macos-26` Apple Silicon runner, checks the installed bundle and Homebrew
quarantine, verifies the ad-hoc code signature, runs `spctl`, and attempts a first
launch with `--sweepdeck-state-directory` pointed at temporary state. This release uses the
no-cost, ad-hoc-signed build. Gatekeeper rejection is recorded as an expected
user-approval requirement only when the bundle signature verifies as ad hoc. Other
assessment failures, broken installs, checksum failures, or uninstall leftovers still
fail the candidate. The job does not approve the app, remove quarantine, disable
Gatekeeper, scan personal folders, or add cask lifecycle scripts. It captures the
disposable runner screen when available so the first-launch UI can be inspected; the
job does not claim that a user-approved launch passed unless that was actually tested.
The public tap's pull-request workflow will repeat audit, style, install, quarantine,
Gatekeeper reporting, and uninstall against the actual versioned GitHub Release URL on
`macos-26` before a cask update can merge.

For GUI launch isolation, the disposable runner passes
`--sweepdeck-state-directory <temporary-directory>` to the app through Launch Services.
This keeps preferences and history in the runner's temporary directory without changing
its launch session configuration.

The post-rebase 0.1.0 candidate check, [Actions run 39644553243](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39644553243),
built the release-shaped 0.1.0 archive and verified its sidecar SHA-256
(`dc0846c0c32722d13ce2587d3f49ee1cd5224c7d2558e4640b1941e63126440e`). Homebrew strict
audit and style, install, app bundle/version and quarantine inspection, and uninstall
passed on the disposable Apple Silicon runner. The installed app contained an arm64
executable; the caveat appeared in Homebrew's install output. The ad-hoc signature
verified, while `spctl --assess --type execute --verbose=4` rejected the quarantined app
with status 3. The captured first-launch dialog said **“Sweepdeck” Not Opened** because
Apple could not verify that it was free of malware; it offered **Move to Trash** and
**Done**. `open -a` did not return within 15 seconds (status 124), though the Sweepdeck
process was observed. The run did not approve the app or verify a post-approval launch.
Both early and final screenshots show the same warning and are attached to the Actions
run for one day. It was a candidate archive through a temporary local tap, not a public
release asset or cask. The earlier style
failure in [run 39639700468](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39639700468)
was fixed before this passing run. See [compatibility evidence](../COMPATIBILITY.md) for
the inspected screen and detailed checks.

As of 2026-10-21, the repository has no `release` GitHub Environment and no
`RELEASE_READY` Actions variable. Before publishing, the maintainer must set
`RELEASE_READY=true` and configure at least one required reviewer on the `release`
environment. The release workflow fails closed without these controls.

The cask belongs in the owner-managed public repository
[`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap), at
`Casks/sweepdeck.rb`. The primary command is
`brew install --cask miguel-osuna/tap/sweepdeck`. Homebrew trusts only that fully
qualified cask for this command. To use the short command, users must run
`brew tap miguel-osuna/tap`, then
`brew trust --cask miguel-osuna/tap/sweepdeck`, then
`brew install --cask sweepdeck`. A fresh Homebrew setup cannot use the short command
without those steps or inclusion in an official tap.

The Homebrew cask and formula API endpoints for `sweepdeck` both returned HTTP 404
on 2026-10-21, confirming the token was available in those official namespaces at
the time of the check. The tap's default branch had no cask at that time; the open
tap PR adds validation and a product-neutral description, not an installable app.

The cask will install only `Sweepdeck.app`; it will have no `zap` stanza or cleanup
scripts, so uninstall will leave preferences and history intact. Cask version updates
are manual and reviewed: after each app release, verify the published `.sha256`, update
the cask's version and checksum while keeping its versioned release URL pattern, and
open a PR in `homebrew-tap`. The tap's disposable macOS CI must pass
`brew audit --cask --strict`, `brew style --cask`, install, bundle/quarantine
inspection, Gatekeeper reporting, and uninstall before that PR is merged. It records
the approval caveat and does not simulate a user's security choice. No cross-repository
Actions token is required for this manual process.

Neither App Store submission nor notarization is required by the cask format. They
remain Gatekeeper compatibility decisions. Homebrew's [official cask acceptance
policy](https://docs.brew.sh/Acceptable-Casks) requires executable artifacts that
Gatekeeper can assess to pass its checks. This owner-managed tap will instead state
clearly that Sweepdeck is ad-hoc signed and may require an explicit user approval on
first launch. That does not make it eligible for the official cask repository or mean
that it passed Gatekeeper. The maintainer has chosen this no-cost, warning-forward
distribution path. Never remove quarantine, disable Gatekeeper, or add cask scripts
that bypass macOS security.

At the 2026-10-21 eligibility check, the canonical Sweepdeck GitHub repository had 0
stars, forks, and watchers and was one day old. Homebrew's [shared package acceptance
policy](https://docs.brew.sh/Package-Acceptance-Policy) normally requires 30 forks or
watchers or 75 stars, increased to 90 forks or watchers or 225 stars for a
self-submission; repositories under 30 days old are normally ineligible. No
official-cask PR is being prepared; these official-tap criteria do not prevent
distribution through the owner-managed tap.

## Dependencies and security

Release tooling is pinned in `package-lock.json` and updated weekly by Dependabot.
The CI audit currently reports eight affected package entries, all tracing to the same
unpatched `braces@3.0.3` issue: [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
It is a dev-only release-tool dependency and is not included in the app. npm's suggested
remediation downgrades semantic-release across a major-version boundary, so CI reports the
finding without applying that downgrade. The release workflow also runs manually on `main`
with a fixed branch pattern. That limits exposure; it does not clear the advisory. Reassess
when upstream ships a fix or semantic-release removes the affected dependency.
