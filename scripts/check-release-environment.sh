#!/usr/bin/env bash
set -euo pipefail

[[ -n "$GITHUB_TOKEN" && -n "$GITHUB_API_URL" && -n "$GITHUB_REPOSITORY" ]] || {
  echo "GitHub release environment configuration is unavailable; refusing to release." >&2
  exit 1
}

environment_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/environments/release"
if ! environment_json="$(curl --fail --silent --show-error \
  -H 'Accept: application/vnd.github+json' \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H 'X-GitHub-Api-Version: 2026-03-10' \
  "$environment_url" 2>/dev/null)"; then
  echo "Could not read the release environment protection rules; refusing to release." >&2
  exit 1
fi

if ! jq -e '[(.protection_rules // [])[] | select(.type == "required_reviewers") | (.reviewers // [])[]] | length > 0' >/dev/null <<< "$environment_json"; then
  echo "Configure at least one required reviewer on the release GitHub Environment; refusing to release." >&2
  exit 1
fi

echo "Release environment has a required reviewer."
