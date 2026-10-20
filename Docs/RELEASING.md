# Release process

Releases are calculated from Conventional Commit messages and are created only from
`main`. Examples:

- `feat: add an export option` requests a minor release.
- `fix: preserve folder selection after refresh` requests a patch release.
- `feat!: change the saved-state format` requests a major release.

The release workflow is manual. Its `publish` input defaults to false, the repository
must have `RELEASE_READY=true`, all supported macOS/Swift CI lanes must pass, and the
`release` GitHub Environment should require a reviewer. The workflow first creates a
versioned candidate build and keeps it as a seven-day Actions artifact. The publish job
waits for the environment review before creating the tag and GitHub Release. If there
is no release-worthy commit, it exits without publishing.

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
and verified on both supported architectures.

## Dependencies and security

Release tooling is pinned in `package-lock.json` and updated weekly by Dependabot.
The current dependency tree includes `braces@3.0.3`, which has the unresolved
[GHSA-vfj7-8cjw-p6xm advisory](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) and no
published patched version. It is a dev-only release-tool dependency, is not included in
the app, and the release workflow runs manually on `main` with a fixed branch pattern.
That limits its exposure; it does not clear the advisory. Reassess when upstream ships
a fix or semantic-release removes the affected dependency.
