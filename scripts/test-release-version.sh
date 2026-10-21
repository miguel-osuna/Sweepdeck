#!/usr/bin/env bash
set -euo pipefail

bash scripts/validate-release-version.sh 0.1.0
bash scripts/validate-release-version.sh 12.34.56

for invalid in "0.1" "0.1.0-rc.1" "01.2.3" "1.2.3; touch /tmp/sweepdeck-release-injected"; do
  if bash scripts/validate-release-version.sh "$invalid" >/dev/null 2>&1; then
    echo "Invalid release version was accepted: $invalid" >&2
    exit 1
  fi
done

echo "Release version validation tests passed."
