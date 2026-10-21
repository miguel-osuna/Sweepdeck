#!/usr/bin/env bash
set -euo pipefail

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/sweepdeck-release-baseline.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT

repository="$fixture_dir/repository"
remote="$fixture_dir/origin.git"
mkdir -p "$repository"
git init --quiet --bare "$remote"
git init --quiet --initial-branch=main "$repository"
git -C "$repository" config user.name "Sweepdeck Test"
git -C "$repository" config user.email "sweepdeck-test@example.invalid"
printf 'initial\n' > "$repository/README.md"
git -C "$repository" add README.md
git -C "$repository" commit --quiet -m "feat: bootstrap test repository"
git -C "$repository" remote add origin "$remote"
git -C "$repository" push --quiet --set-upstream origin main

root_commit="$(git -C "$repository" rev-list --max-parents=0 HEAD)"
(
  cd "$repository"
  bash "$script_root/scripts/ensure-release-baseline.sh"
)

local_baseline="$(git -C "$repository" rev-parse 'refs/tags/v0.0.0^{}')"
remote_baseline="$(git --git-dir="$remote" rev-parse 'refs/tags/v0.0.0^{}')"
[[ "$local_baseline" == "$root_commit" && "$remote_baseline" == "$root_commit" ]] || {
  echo "The bootstrap tag must point to the repository root commit." >&2
  exit 1
}

(
  cd "$repository"
  bash "$script_root/scripts/ensure-release-baseline.sh"
)

printf 'later commit\n' >> "$repository/README.md"
git -C "$repository" add README.md
git -C "$repository" commit --quiet -m "feat: add a later change"
git -C "$repository" tag --force --annotate v0.0.0 --message "Incorrect baseline" HEAD

if (
  cd "$repository"
  bash "$script_root/scripts/ensure-release-baseline.sh"
) > "$fixture_dir/rejected.log" 2>&1; then
  echo "An existing v0.0.0 tag away from the root commit was accepted." >&2
  exit 1
fi

remote_baseline="$(git --git-dir="$remote" rev-parse 'refs/tags/v0.0.0^{}')"
[[ "$remote_baseline" == "$root_commit" ]] || {
  echo "The release baseline test unexpectedly changed the remote tag." >&2
  exit 1
}

echo "Release baseline tests passed."
