# Release process

Releases are calculated from Conventional Commit messages and created only from
`main`:

- `feat: add an export option` requests a minor release.
- `fix: preserve folder selection after refresh` requests a patch release.
- `feat!: change the saved-state format` requests a major release.

The manual Release workflow defaults `publish` to false and refuses any ref except
`main`. It requires `RELEASE_READY=true` and verifies that the `release` GitHub
Environment has a required reviewer before doing release work. The workflow runs the
supported macOS/Swift verification lanes, builds a versioned app candidate, and tests
that exact candidate with Homebrew on a disposable Apple Silicon runner. The publish
job uses the protected environment and pauses for reviewer approval before creating
the tag and GitHub Release. If there is no release-worthy commit, it exits without
publishing.

The first publish creates and validates the `v0.0.0` analysis baseline at the
repository's root commit, then requires semantic-release to propose exactly `0.1.0`.
Later versions follow Conventional Commit rules. Release tooling is not published as
an npm package.

## Published release

Version [0.1.0](https://github.com/miguel-osuna/Sweepdeck/releases/tag/v0.1.0) was
published from `main` on 2026-10-21 after the required environment approval. The
complete [release workflow run](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39658605258)
passed. It publishes the app-only archive
[`Sweepdeck-0.1.0-macOS.zip`](https://github.com/miguel-osuna/Sweepdeck/releases/download/v0.1.0/Sweepdeck-0.1.0-macOS.zip)
and its `.sha256` sidecar. The verified archive SHA-256 is
`383034386df5a692a687df6ff1b70ea088791df304dd8de568069da2fd097789`.

The 0.1.0 archive was built before the app icon was added. The cask is intentionally
waiting for the next icon-bearing app release so that the first Homebrew install
includes the selected icon artwork.

## Homebrew distribution

The maintained public tap is [`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap),
with the cask at `Casks/sweepdeck.rb`. Its open [PR #1](https://github.com/miguel-osuna/homebrew-tap/pull/1)
adds a validation workflow and a product-neutral repository description; it does not
yet contain an installable cask. The tap PR will add the cask only after the matching
versioned GitHub Release asset is public.

The primary install command, once the cask is merged, is:

```sh
brew install --cask miguel-osuna/tap/sweepdeck
```

Homebrew trusts only that fully qualified cask for this command. To install by short
name, users must first run:

```sh
brew tap miguel-osuna/tap
brew trust --cask miguel-osuna/tap/sweepdeck
brew install --cask sweepdeck
```

The short command does not work from a fresh Homebrew setup without those steps or
inclusion in an official tap. The cask will install only `Sweepdeck.app`, contain no
`zap` stanza or cleanup scripts, and preserve Sweepdeck preferences and history on
uninstall.

Cask updates are manual and reviewed. After each app release, verify the published
`.sha256`, update the cask version and versioned release URL, and open a pull request
in `homebrew-tap`. Its disposable macOS checks must pass `brew audit --cask --strict`,
`brew style --cask`, install, installed-bundle and quarantine inspection, Gatekeeper
reporting, and uninstall before merge. The workflow installs only the app and does
not use cask scripts to bypass Gatekeeper. No cross-repository Actions token is needed.

## Gatekeeper and official cask eligibility

The no-cost release is ad-hoc signed and has no Apple-issued Developer ID signature or
notarization ticket. On the disposable macOS 26 Apple Silicon runner, the Homebrew
candidate check passed audit, style, install, quarantine inspection, and uninstall.
`spctl --assess --type execute --verbose=4` rejected the quarantined app with status 3.
The first-launch screen said **“Sweepdeck” Not Opened** because Apple could not verify
that the app was free of malware; it offered **Move to Trash** and **Done**. The check
did not approve the app or verify a successful launch after approval. The release
workflow leaves quarantine intact, does not disable Gatekeeper, and does not scan
personal folders.

Users who choose to proceed can select **Done**, then check **System Settings >
Privacy & Security** for **Open Anyway** after attempting to open the app. Read Apple's
[security guidance](https://support.apple.com/en-au/102445) and continue only if the
app and its source are trusted. The cask will describe this approval step; it will not
automate it. App Store submission and notarization are not cask-format requirements;
they remain Gatekeeper compatibility decisions.

The official Homebrew cask was not pursued. Its [acceptance policy](https://docs.brew.sh/Acceptable-Casks)
requires Gatekeeper-compatible executable artifacts. The [shared package policy](https://docs.brew.sh/Package-Acceptance-Policy)
also has notability and repository-age thresholds. Those requirements do not prevent
use of the owner-managed tap.

At the 2026-10-21 eligibility check, Sweepdeck's canonical repository had 0 stars,
forks, and watchers and was one day old. The shared package policy normally requires
30 forks or watchers or 75 stars, increased to 90 forks or watchers or 225 stars for
a self-submission; repositories under 30 days old are normally ineligible.

## Release tooling security

Release tooling is pinned in `package-lock.json` and updated weekly by Dependabot. CI
reports eight affected package entries tracing to the same unpatched
[`braces@3.0.3` advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm). This is
a dev-only release-tool dependency and is not included in the app. npm's suggested
remediation downgrades semantic-release across a major-version boundary, so CI reports
the finding without applying that downgrade. Reassess when upstream ships a fix or
semantic-release removes the affected dependency.
