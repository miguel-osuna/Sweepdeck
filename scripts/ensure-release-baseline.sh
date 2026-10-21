#!/usr/bin/env bash
set -euo pipefail

other_release_tags="$(git tag --list 'v[0-9]*' | grep -Fvx 'v0.0.0' || true)"
if [[ -n "$other_release_tags" ]]; then
  echo "An earlier semantic release exists; no baseline tag is needed."
  exit 0
fi

root_commit="$(git rev-list --max-parents=0 HEAD)"
root_count="$(git rev-list --max-parents=0 HEAD | wc -l | tr -d ' ')"
if [[ "$root_count" != "1" ]]; then
  echo "Expected one repository root commit; create the v0.0.0 baseline manually." >&2
  exit 1
fi

if git show-ref --verify --quiet refs/tags/v0.0.0; then
  baseline_commit="$(git rev-parse 'refs/tags/v0.0.0^{commit}')"
  if [[ "$baseline_commit" != "$root_commit" ]]; then
    echo "The v0.0.0 baseline must point to the repository root commit; refusing to release." >&2
    exit 1
  fi
  echo "The v0.0.0 baseline already points to the repository root commit."
  exit 0
fi

git tag --annotate v0.0.0 --message "Semantic-release bootstrap baseline" "$root_commit"
git push origin refs/tags/v0.0.0
echo "Created the v0.0.0 analysis baseline at $root_commit."
