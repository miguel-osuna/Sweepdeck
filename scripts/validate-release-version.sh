#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
if [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  exit 0
fi

echo "Expected a stable three-part numeric version; received: $version" >&2
exit 64
