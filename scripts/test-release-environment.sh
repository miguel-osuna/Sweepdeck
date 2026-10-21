#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin"

cat > "$fixture_dir/bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == *"/repos/miguel-osuna/Sweepdeck/environments/release"* ]]
[[ "$*" == *"Authorization: Bearer test-token"* ]]
[[ "$*" == *"X-GitHub-Api-Version: 2026-03-10"* ]]
if [[ "$MOCK_CURL_FAIL" == "true" ]]; then
  exit 22
fi
printf '%s' "$MOCK_ENVIRONMENT_JSON"
MOCK_CURL
chmod +x "$fixture_dir/bin/curl"

export PATH="$fixture_dir/bin:$PATH"
export GITHUB_TOKEN="test-token"
export GITHUB_API_URL="https://api.github.com"
export GITHUB_REPOSITORY="miguel-osuna/Sweepdeck"
export MOCK_CURL_FAIL="false"

MOCK_ENVIRONMENT_JSON='{"protection_rules":[{"type":"required_reviewers","reviewers":[{"type":"User"}]}]}' \
  bash scripts/check-release-environment.sh >/dev/null

expect_rejection() {
  if "$@" >/dev/null 2>&1; then
    echo "Expected the release environment check to reject this configuration." >&2
    exit 1
  fi
}

expect_rejection env MOCK_ENVIRONMENT_JSON='{"protection_rules":[]}' MOCK_CURL_FAIL=false bash scripts/check-release-environment.sh
expect_rejection env MOCK_ENVIRONMENT_JSON='{"protection_rules":[{"type":"branch_policy"}]}' MOCK_CURL_FAIL=false bash scripts/check-release-environment.sh
expect_rejection env MOCK_ENVIRONMENT_JSON='{}' MOCK_CURL_FAIL=true bash scripts/check-release-environment.sh

echo "Release environment reviewer gate tests passed."
