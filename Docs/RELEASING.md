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

The 0.1.0 archive was built before the app icon was added. The icon-bearing 0.2.0
release was published from `main` after the required environment approval. The complete
[release run 39664467890](https://github.com/miguel-osuna/Sweepdeck/actions/runs/39664467890)
passed. Its app-only archive includes `Sweepdeck.icns`; the public archive and sidecar
were independently downloaded and verified against the same SHA-256:
`e31d64f80948461fe0f92d5c482c8f11c8f364ca81f8c326a40f8db8d2dbd760`.
The first-launch screen showed the Gatekeeper malware-verification warning; the check
did not approve the app or verify a successful post-approval launch.

## Homebrew distribution

The maintained public tap is [`miguel-osuna/homebrew-tap`](https://github.com/miguel-osuna/homebrew-tap).
Tap PR [#1](https://github.com/miguel-osuna/homebrew-tap/pull/1) added its validation
workflow and a product-neutral repository description. Tap PR
[#2](https://github.com/miguel-osuna/homebrew-tap/pull/2) merged `Casks/sweepdeck.rb`
against the public 0.2.0 assets after its disposable macOS validation passed in
[tap run 39676510862](https://github.com/miguel-osuna/homebrew-tap/actions/runs/39676510862).
That run passed strict audit, style, install, quarantine and bundle inspection,
Gatekeeper/first-launch reporting, and uninstall.

The primary install command is:

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
inclusion in an official tap. The published cask installs only `Sweepdeck.app`, contains
no `zap` stanza or cleanup scripts, and preserves Sweepdeck preferences and history on
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

Users who choose to proceed can select **Done**, open **System Settings > Privacy &
Security**, scroll to **Security**, and click **Open Anyway** for Sweepdeck. After the
warning appears again, they can click **Open** if they still trust the app and its
source. Apple says this saves an exception for the app so future launches work
normally. See Apple's [security guidance](https://support.apple.com/en-au/102445).
The cask describes this approval step; it does not automate it. This is a local,
per-app exception, not a global Gatekeeper setting.

Changing the archive from ZIP to DMG can offer a familiar drag-to-Applications step,
but it does not establish the developer's identity or provide a notarization ticket.
It therefore does not resolve this Gatekeeper warning. To avoid this
malware-verification block and the **Open Anyway** exception workflow, the release
must be signed with an Apple Developer ID and notarized. macOS may still ask users to
confirm opening a downloaded app the first time. Apple requires an Apple Developer
Program Account Holder to create a Developer ID certificate. The program currently
costs USD 99 per year in the United States (regional pricing and limited organization
fee waivers may differ; see Apple's [membership
terms](https://developer.apple.com/help/account/membership/program-enrollment)). The
current no-cost release path keeps quarantine enabled and documents the one-time user
approval. App Store submission and notarization are not cask-format requirements;
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
