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
root commit. The workflow refuses to publish if semantic-release does not propose
exactly `0.1.0` as the first release. Subsequent versions follow Conventional Commit
rules. The release tool does not publish an npm package.

## Distribution status

The current workflow publishes GitHub release notes and source archives. The candidate
app is an Actions artifact for manual QA; it is not attached to the public release.
Local app builds are ad-hoc signed and are not notarized. Do not advertise the current
archive as a one-click public installer or create a Homebrew cask until Developer ID
signing, hardened runtime, notarization, stapling and installation checks are automated
and verified on supported macOS releases and Apple Silicon.

## Dependencies and security

Release tooling is pinned in `package-lock.json` and updated weekly by Dependabot.
The CI audit currently reports eight affected package entries, all tracing to the same
unpatched `braces@3.0.3` issue: [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm).
It is a dev-only release-tool dependency and is not included in the app. npm's suggested
remediation downgrades semantic-release across a major-version boundary, so CI reports the
finding without applying that downgrade. The release workflow also runs manually on `main`
with a fixed branch pattern. That limits exposure; it does not clear the advisory. Reassess
when upstream ships a fix or semantic-release removes the affected dependency.
