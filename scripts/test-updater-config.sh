#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - Resources/Info.plist <<'PY'
import base64
import plistlib
import sys
from pathlib import Path

with Path(sys.argv[1]).open("rb") as stream:
    info = plistlib.load(stream)

expected = {
    "SUFeedURL": "https://miguel-osuna.github.io/Sweepdeck/appcast.xml",
    "SUPublicEDKey": "0Qm9EttnzanTlTUzHHkr9P30npDDAIVCvS1jOTnOswM=",
    "SUAutomaticallyUpdate": False,
    "SUAllowsAutomaticUpdates": False,
    "SUEnableSystemProfiling": False,
    "SUVerifyUpdateBeforeExtraction": True,
    "SURequireSignedFeed": True,
    "SUSignedFeedFailureExpirationInterval": 0,
}
for key, value in expected.items():
    if info.get(key) != value:
        raise SystemExit(f"{key}: expected {value!r}, got {info.get(key)!r}")

if "SUEnableAutomaticChecks" in info:
    raise SystemExit("SUEnableAutomaticChecks must remain absent so Sparkle asks for consent")
if any(key.startswith("SweepdeckTest") for key in info):
    raise SystemExit("Test-only updater behavior must not be present in the production bundle")

try:
    public_key = base64.b64decode(info["SUPublicEDKey"], validate=True)
except (KeyError, ValueError) as error:
    raise SystemExit(f"SUPublicEDKey must be valid base64: {error}")
if len(public_key) != 32:
    raise SystemExit(f"SUPublicEDKey must decode to 32 bytes, got {len(public_key)}")

print("Sparkle feed, signing, privacy, and opt-in defaults passed.")
PY
