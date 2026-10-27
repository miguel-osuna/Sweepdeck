#!/usr/bin/env bash
set -euo pipefail

bash scripts/validate-release-version.sh 0.1.0
bash scripts/validate-release-version.sh 12.34.56

assert_next_test_version() {
  local input="$1" expected="$2" actual
  if ! actual="$(bash scripts/next-test-update-version.sh "$input")"; then
    echo "Could not derive the test update version from $input." >&2
    exit 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $input to advance to $expected, got $actual." >&2
    exit 1
  fi
}

assert_next_test_version 0.4.0 0.4.1
assert_next_test_version 1.2.9 1.2.10
assert_next_test_version 12.34.56 12.34.57

for invalid in "0.1" "0.1.0-rc.1" "01.2.3" "1.2.3; touch /tmp/sweepdeck-release-injected"; do
  if bash scripts/validate-release-version.sh "$invalid" >/dev/null 2>&1; then
    echo "Invalid release version was accepted: $invalid" >&2
    exit 1
  fi
done

echo "Release version validation tests passed."
