#!/usr/bin/env bash
set -euo pipefail

other_release_tags="$(git tag --list 'v[0-9]*' | grep -Ev '^v0\\.0\\.0$' || true)"
if [[ -n "$other_release_tags" ]]; then
  echo "An earlier semantic release exists; no baseline tag is needed."
  exit 0
fi

if git show-ref --verify --quiet refs/tags/v0.0.0; then
  echo "The v0.0.0 baseline already exists."
  exit 0
fi

roots="$(git rev-list --max-parents=0 HEAD)"
root_count="$(printf '%s\\n' "$roots" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$root_count" != "1" ]]; then
  echo "Expected one repository root commit; create the v0.0.0 baseline manually." >&2
  exit 1
fi

root_commit="$(printf '%s\\n' "$roots" | sed -n '1p')"
git tag --annotate v0.0.0 --message "Semantic-release bootstrap baseline" "$root_commit"
git push origin refs/tags/v0.0.0
echo "Created the v0.0.0 analysis baseline at $root_commit."
