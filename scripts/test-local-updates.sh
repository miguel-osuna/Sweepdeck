#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The local Sparkle update test requires macOS." >&2
  exit 1
fi

test_mode="${1:-manual}"
case "$test_mode" in
  manual|automatic|deferral|offline|tampered|published) ;;
  *)
    echo "Usage: $0 [manual|automatic|deferral|offline|tampered|published]" >&2
    exit 64
    ;;
esac

key_account="${SPARKLE_KEYCHAIN_ACCOUNT:-sweepdeck}"
default_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
old_version="${SWEEPDECK_TEST_OLD_VERSION:-$default_version}"
update_version="${SWEEPDECK_TEST_UPDATE_VERSION:-0.4.0}"
candidate_update_app="${SWEEPDECK_TEST_UPDATE_APP:-}"
if [[ "$test_mode" == published ]]; then
  if [[ -z "${SWEEPDECK_TEST_UPDATE_VERSION:-}" ]]; then
    echo "SWEEPDECK_TEST_UPDATE_VERSION is required for the published-feed test." >&2
    exit 64
  fi
  feed_url="${SWEEPDECK_TEST_FEED_URL:-https://miguel-osuna.github.io/Sweepdeck/appcast.xml}"
  if [[ "$feed_url" != https://* ]]; then
    echo "The published-feed test requires an HTTPS appcast URL." >&2
    exit 64
  fi
else
  feed_url=""
fi
python3 - "$old_version" "$update_version" <<'PY'
import sys

def parse(version):
    parts = version.split(".")
    if len(parts) != 3 or not all(part.isdecimal() for part in parts):
        raise SystemExit(f"Invalid test version: {version}")
    return tuple(map(int, parts))

if parse(sys.argv[1]) >= parse(sys.argv[2]):
    raise SystemExit("The test update version must be greater than the old version.")
PY
if [[ -n "$candidate_update_app" && ! -d "$candidate_update_app" ]]; then
  echo "Candidate update app not found: $candidate_update_app" >&2
  exit 66
fi
test_temp="${RUNNER_TEMP:-${TMPDIR:-/private/tmp}}"
workspace="$(mktemp -d "$test_temp/Sweepdeck-local-update.XXXXXX")"
workspace="$(cd -P "$workspace" && pwd -P)"
bundle_suffix="${workspace##*.}"
bundle_id="local.sweepdeck.updatetest.${bundle_suffix}"
old_app="$workspace/Sweepdeck.app"
update_app="$workspace/update-build/Sweepdeck.app"
updates_dir="$workspace/updates"
state_dir="$workspace/isolated-state"
app_state_dir="$state_dir"
launch_marker="$state_dir/launches.log"
scan_fixture="$workspace/authorized-scan-fixture"
port="$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
if [[ "$test_mode" != published ]]; then
  feed_url="http://127.0.0.1:${port}/appcast.xml"
fi
server_pid=""

stop_server() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap stop_server EXIT

test_app_pids() (
  export SWEEPDECK_TEST_PROCESS_PATH="$old_app/Contents/MacOS/Sweepdeck"
  ps -ww -axo pid=,command= | awk 'index($0, ENVIRON["SWEEPDECK_TEST_PROCESS_PATH"]) { print $1 }'
)

wait_for_local_test_app_to_close() {
  [[ "$test_mode" != published && -t 0 ]] || return 0

  case "$test_mode" in
    offline)
      echo "The offline test feed remains stopped while you inspect the isolated app."
      ;;
    *)
      echo "The localhost update feed remains available while you inspect the isolated app."
      ;;
  esac
  echo "Quit the isolated test app when you are done; this script will then stop the feed and exit."
  while [[ -n "$(test_app_pids)" ]]; do sleep 1; done
}

installed_info="/Applications/Sweepdeck.app/Contents/Info.plist"
installed_info_hash=""
installed_version=""
installed_app_existed=false
if [[ "$test_mode" == published ]]; then
  if [[ "${GITHUB_ACTIONS:-}" != true || "${SWEEPDECK_DISPOSABLE_RUNNER:-}" != true ]]; then
    echo "The published-feed test must run only on a disposable runner." >&2
    exit 64
  fi
  if [[ -z "${RUNNER_TEMP:-}" || ! -d "$RUNNER_TEMP" || ! -w "$RUNNER_TEMP" ]]; then
    echo "The published-feed test requires a writable GitHub Actions RUNNER_TEMP directory." >&2
    exit 64
  fi
  if [[ ! "${GITHUB_RUN_ID:-}" =~ ^[0-9]+$ || ! "${GITHUB_RUN_ATTEMPT:-}" =~ ^[0-9]+$ ]]; then
    echo "The published-feed test requires a GitHub Actions run ID and attempt." >&2
    exit 64
  fi
  if [[ -e "/Applications/Sweepdeck.app" ]]; then
    echo "Refusing the published-feed test because /Applications/Sweepdeck.app exists." >&2
    exit 1
  fi
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"
  app_state_dir="$HOME/Library/Application Support/Sweepdeck"
  if [[ -e "$app_state_dir" ]]; then
    echo "Refusing the published-feed test because its Application Support directory already exists." >&2
    exit 1
  fi
  if defaults read "$bundle_id" >/dev/null 2>&1; then
    echo "Refusing the published-feed test because its bundle defaults already exist." >&2
    exit 1
  fi
fi
if [[ -f "$installed_info" ]]; then
  installed_app_existed=true
  installed_info_hash="$(shasum -a 256 "$installed_info" | awk '{print $1}')"
  installed_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$installed_info")"
fi

mkdir -p "$updates_dir" "$state_dir" "$app_state_dir"
printf 'isolated update test state\n' > "$state_dir/keep.txt"
python3 - "$app_state_dir/state.json" "$test_mode" <<'PY'
import json
import sys
import uuid
from pathlib import Path

item_id = str(uuid.uuid4())
record_id = str(uuid.uuid4())
state = {
    "version": 1,
    "preferences": {
        "roots": [],
        "excludedPaths": [],
        "enabledRules": ["installers", "oldDownloads", "logs", "largeFiles"],
        "ageDays": 60,
        "minimumLargeMB": 500,
        "appearance": "Dark",
    },
    "history": [{
        "id": record_id,
        "date": 0,
        "items": [{
            "id": item_id,
            "path": "isolated-update-test-marker",
            "status": "rejected",
            "message": "preserve this local history entry",
            "trashPath": None,
        }],
    }],
    "lastScan": None,
}
Path(sys.argv[1]).write_text(json.dumps(state, indent=2) + "\n")
PY
state_hash_before="$(shasum -a 256 "$app_state_dir/state.json" | awk '{print $1}')"

SWEEPDECK_BUILD_STAGE="$workspace/template-stage" \
SWEEPDECK_ARCHIVE_PATH="$workspace/template.zip" \
SWEEPDECK_SKIP_DIST_ALIAS=1 \
  bash scripts/build-app.sh

ditto "$workspace/template-stage/Sweepdeck.app" "$old_app"
bash scripts/set-app-version.sh "$old_app/Contents/Info.plist" "$old_version"
if [[ "$test_mode" != published ]]; then
  if [[ -n "$candidate_update_app" ]]; then
    ditto "$candidate_update_app" "$update_app"
    candidate_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$update_app/Contents/Info.plist")"
    [[ "$candidate_version" == "$update_version" ]] || {
      echo "Candidate app version $candidate_version does not match requested test version $update_version." >&2
      exit 65
    }
  else
    ditto "$workspace/template-stage/Sweepdeck.app" "$update_app"
    bash scripts/set-app-version.sh "$update_app/Contents/Info.plist" "$update_version"
  fi
fi

configure_test_app() {
  local app="$1"
  python3 - "$app/Contents/Info.plist" "$feed_url" "$app_state_dir" "$bundle_id" "$test_mode" "${SPARKLE_EDDSA_PUBLIC_KEY:-}" "$launch_marker" "$bundle_suffix" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open("rb") as stream:
    info = plistlib.load(stream)
info["CFBundleIdentifier"] = sys.argv[4]
test_app_name = f"Sweepdeck Update Test {sys.argv[8]}"
info["CFBundleName"] = test_app_name
info["CFBundleDisplayName"] = test_app_name
info["SUFeedURL"] = sys.argv[2]
info["SweepdeckStateDirectory"] = sys.argv[3]
if sys.argv[5] != "published":
    info["NSAppTransportSecurity"] = {"NSAllowsLocalNetworking": True}
if sys.argv[6]:
    info["SUPublicEDKey"] = sys.argv[6]
info["SweepdeckTestLaunchMarker"] = sys.argv[7]
automatic = sys.argv[5] in {"automatic", "published"}
info["SUEnableAutomaticChecks"] = automatic
info["SUAutomaticallyUpdate"] = automatic
info["SUAllowsAutomaticUpdates"] = True
info["SUEnableSystemProfiling"] = False
info["SUVerifyUpdateBeforeExtraction"] = True
info["SURequireSignedFeed"] = True
info["SUSignedFeedFailureExpirationInterval"] = 0
if automatic:
    info["SweepdeckTestQuitAfterAutomaticDownload"] = True
else:
    info.pop("SweepdeckTestQuitAfterAutomaticDownload", None)
with path.open("wb") as stream:
    plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=False)
PY
  codesign --force --sign - "$app"
  codesign --verify --deep --strict "$app"
}

configure_test_app "$old_app"
if [[ "$test_mode" != published ]]; then
  configure_test_app "$update_app"
fi
defaults delete "$bundle_id" >/dev/null 2>&1 || true
if [[ "$test_mode" == automatic || "$test_mode" == published ]]; then
  defaults write "$bundle_id" SUEnableAutomaticChecks -bool true
  defaults write "$bundle_id" SUAutomaticallyUpdate -bool true
fi
if [[ "$test_mode" != published ]]; then
ditto -c -k --keepParent --norsrc --noextattr --noqtn \
  "$update_app" "$updates_dir/Sweepdeck-${update_version}-macOS.zip"

sparkle_key_args=(--account "$key_account")
sparkle_verify_args=(--account "$key_account")
if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  sparkle_key_args=(--ed-key-file -)
  sparkle_verify_args=(--ed-key-file -)
  printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" | \
    .build/dependencies/sparkle/bin/generate_appcast \
      "${sparkle_key_args[@]}" \
      --download-url-prefix "http://127.0.0.1:${port}/" \
      "$updates_dir"
else
  .build/dependencies/sparkle/bin/generate_appcast \
    "${sparkle_key_args[@]}" \
    --download-url-prefix "http://127.0.0.1:${port}/" \
    "$updates_dir"
fi
if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" | \
    .build/dependencies/sparkle/bin/sign_update \
      "${sparkle_verify_args[@]}" --verify "$updates_dir/appcast.xml"
else
    .build/dependencies/sparkle/bin/sign_update \
      "${sparkle_verify_args[@]}" --verify "$updates_dir/appcast.xml"
fi
archive="$updates_dir/Sweepdeck-${update_version}-macOS.zip"
archive_signature="$(python3 - "$updates_dir/appcast.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
enclosure = root.find("./channel/item/enclosure")
if enclosure is None:
    raise SystemExit("The appcast is missing its update archive enclosure.")
signature = enclosure.attrib.get("{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature")
if not signature:
    raise SystemExit("The appcast is missing the archive EdDSA signature.")
print(signature)
PY
)"
if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" | \
    .build/dependencies/sparkle/bin/sign_update \
      "${sparkle_verify_args[@]}" --verify "$archive" "$archive_signature"
else
  .build/dependencies/sparkle/bin/sign_update \
    "${sparkle_verify_args[@]}" --verify "$archive" "$archive_signature"
fi
cp "$archive" "$workspace/tampered.zip"
python3 - "$workspace/tampered.zip" <<'PY'
import sys
from pathlib import Path

archive = Path(sys.argv[1])
archive.write_bytes(archive.read_bytes() + b"tamper")
PY
if [[ -n "${SPARKLE_EDDSA_PRIVATE_KEY:-}" ]]; then
  if printf '%s' "$SPARKLE_EDDSA_PRIVATE_KEY" | \
    .build/dependencies/sparkle/bin/sign_update \
      "${sparkle_verify_args[@]}" --verify "$workspace/tampered.zip" "$archive_signature" \
      > "$workspace/tampered-verification.log" 2>&1; then
    echo "Sparkle accepted the modified update archive signature." >&2
    exit 1
  fi
else
  if .build/dependencies/sparkle/bin/sign_update \
    "${sparkle_verify_args[@]}" --verify "$workspace/tampered.zip" "$archive_signature" \
    > "$workspace/tampered-verification.log" 2>&1; then
    echo "Sparkle accepted the modified update archive signature." >&2
    exit 1
  fi
fi
echo "PASS: the original update archive signature verifies; a modified archive is rejected."

if [[ "$test_mode" == tampered ]]; then
  cp "$archive" "$workspace/valid-update.zip"
  python3 - "$archive" <<'PY'
import sys
from pathlib import Path

archive = Path(sys.argv[1])
archive.write_bytes(archive.read_bytes() + b"tamper")
PY
fi
else
  curl --fail --location --silent --show-error "$feed_url" \
    --output "$workspace/published-appcast.xml"
  python3 - "$workspace/published-appcast.xml" "$update_version" <<'PY'
import sys
import xml.etree.ElementTree as ET

feed_path, expected_version = sys.argv[1:]
root = ET.parse(feed_path).getroot()
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
item = root.find("./channel/item")
if item is None:
    raise SystemExit("The published appcast has no latest update item.")
version = item.find(f"{sparkle}version")
if version is None or version.text != expected_version:
    raise SystemExit("The published appcast latest version does not match the release.")
enclosure = item.find("enclosure")
if enclosure is None:
    raise SystemExit("The published appcast has no update archive enclosure.")
url = enclosure.attrib.get("url", "")
expected_archive = f"Sweepdeck-{expected_version}-macOS.zip"
if not url.startswith("https://") or not url.endswith(expected_archive):
    raise SystemExit("The published appcast does not link to the expected HTTPS release ZIP.")
signature = enclosure.attrib.get(f"{sparkle}edSignature", "")
if not signature:
    raise SystemExit("The published release archive does not have an EdDSA signature.")
print(f"Verified public feed version {expected_version}: {url}")
PY
fi

if [[ "$test_mode" != offline && "$test_mode" != published ]]; then
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$updates_dir" \
    > "$workspace/http.log" 2>&1 &
  server_pid=$!
  for _ in {1..30}; do
    if curl --fail --silent "$feed_url" --output /dev/null; then break; fi
    sleep 1
  done
  curl --fail --silent "$feed_url" --output /dev/null
fi

if [[ "$test_mode" == deferral ]]; then
  mkdir -p "$scan_fixture"
  python3 - "$scan_fixture" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
for bucket_index in range(250):
    bucket = root / f"bucket-{bucket_index:03d}"
    bucket.mkdir()
    for fixture_index in range(99):
        (bucket / f"fixture-{fixture_index:03d}").mkdir()
PY
fi

open -n "$old_app"
old_pid=""
for _ in {1..30}; do
  old_pid="$(test_app_pids | awk 'NR == 1 { first = $1 } END { print first }')"
  [[ -n "$old_pid" ]] && break
  sleep 1
done
if [[ -z "$old_pid" ]]; then
  echo "The test app did not launch. Bundle: $old_app" >&2
  exit 1
fi
for _ in {1..30}; do
  if [[ -s "$launch_marker" ]] && awk -v version="$old_version" '$1 == version { found = 1 } END { exit !found }' "$launch_marker"; then
    break
  fi
  sleep 1
done
initial_launch_pid="$(awk -v version="$old_version" '$1 == version { print $2; exit }' "$launch_marker" 2>/dev/null || true)"
if [[ "$initial_launch_pid" != "$old_pid" ]]; then
  echo "The test app's launch marker did not match its running process." >&2
  exit 1
fi

case "$test_mode" in
  manual)
    echo "In the isolated app, open Settings and confirm Dark appearance plus the seeded history entry."
    echo "Then run Check for Updates… and approve $update_version."
    echo "After it relaunches, check again; the live feed should report that the app is up to date."
    ;;
  automatic)
    echo "Automatic checks and background installation are enabled only in this isolated test app."
    echo "The isolated app will quit normally after download; Sparkle installs on quit, then the harness launches the updated app for validation."
    ;;
  deferral)
    echo "Authorize and scan only this temporary fixture folder: $scan_fixture"
    echo "While scanning, check for $update_version, download it, then choose Install and Relaunch."
    echo "Confirm relaunch waits until the temporary scan finishes. Do not clean any files."
    ;;
  offline)
    echo "The loopback server is intentionally stopped. Run Check for Updates… and confirm Sparkle reports the feed is unreachable."
    ;;
  tampered)
    echo "The signed feed is valid, but the ZIP bytes have been changed. Check for Updates… and try to install $update_version."
    echo "Confirm Sparkle rejects the archive and the app remains at $old_version."
    ;;
  published)
    echo "This isolated app uses the public HTTPS appcast and actual GitHub Release ZIP."
    echo "Automatic checks and installation are enabled only in this test bundle."
    ;;
esac
echo "Temporary app: $old_app"
if [[ "$test_mode" == published ]]; then
  echo "Disposable-runner bundle ID: $bundle_id"
else
  echo "Isolated test bundle ID: $bundle_id"
fi
if [[ "$test_mode" != published ]]; then echo "Signed appcast: $updates_dir/appcast.xml"; fi
if [[ "$test_mode" != offline && "$test_mode" != published ]]; then echo "Loopback server log: $workspace/http.log"; fi

if [[ "$test_mode" == offline || "$test_mode" == tampered ]]; then
  read -r -p "After verifying the expected failure in the test app, press Return here: "
  current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$old_app/Contents/Info.plist")"
  current_pid="$(test_app_pids | awk 'NR == 1 { first = $1 } END { print first }')"
  [[ "$current_version" == "$old_version" && -n "$current_pid" ]] || {
    echo "Expected the isolated app to remain running at version $old_version after the failed update." >&2
    exit 1
  }
  [[ "$(<"$state_dir/keep.txt")" == "isolated update test state" ]]
  echo "PASS: the app stayed on $old_version after the $test_mode update failure."
  echo "Test app for inspection: $old_app"
  wait_for_local_test_app_to_close
  exit 0
fi

echo "Waiting up to 5 minutes for Sparkle to install version ${update_version}…"

updated=false
current_pid=""
updated_launch_pid=""
automatic_test_launch_requested=false
for _ in {1..300}; do
  current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$old_app/Contents/Info.plist" 2>/dev/null || true)"
  current_pids="$(test_app_pids)"
  current_pid="$(printf '%s\n' "$current_pids" | awk 'NF && NR == 1 { first = $1 } END { print first }')"
  if { [[ "$test_mode" == automatic ]] || [[ "$test_mode" == published ]]; } && \
    [[ "$current_version" == "$update_version" && -z "$current_pid" && "$automatic_test_launch_requested" != true ]]; then
    open -n "$old_app"
    automatic_test_launch_requested=true
  fi
  if [[ "$test_mode" == published ]]; then
    if [[ "$current_version" == "$update_version" && -n "$current_pid" && "$current_pid" != "$old_pid" ]]; then
      updated=true
      break
    fi
  else
    updated_launch_pid="$(awk -v version="$update_version" '$1 == version { print $2; exit }' "$launch_marker" 2>/dev/null || true)"
    if [[ "$current_version" == "$update_version" && -n "$updated_launch_pid" && "$updated_launch_pid" != "$old_pid" ]] && \
      printf '%s\n' "$current_pids" | awk -v pid="$updated_launch_pid" '$1 == pid { found = 1 } END { exit !found }'; then
      current_pid="$updated_launch_pid"
      updated=true
      break
    fi
  fi
  sleep 1
done

if [[ "$updated" != true ]]; then
  echo "Final app version: ${current_version:-unknown}"
  echo "Final app processes: ${current_pids:-none}"
  if [[ -f "$launch_marker" ]]; then
    echo "Launch markers:"
    cat "$launch_marker"
  else
    echo "No app launch markers were recorded."
  fi
  if [[ -f "$workspace/http.log" ]]; then
    echo "Loopback feed requests:"
    cat "$workspace/http.log"
  fi
  echo "Recent app log:"
  log show --last 10m --style compact --predicate 'process == "Sweepdeck"' 2>/dev/null | tail -n 80 || true
  echo "Timed out waiting for the app bundle to update and launch. It remains at $old_app for inspection." >&2
  exit 1
fi

test_app_process_count="$(test_app_pids | awk 'END { print NR + 0 }')"
[[ "$test_app_process_count" == 1 ]] || {
  echo "Expected exactly one isolated test app process after update; found $test_app_process_count." >&2
  exit 1
}

codesign --verify --deep --strict "$old_app"
[[ "$(<"$state_dir/keep.txt")" == "isolated update test state" ]]
state_hash_after="$(shasum -a 256 "$app_state_dir/state.json" | awk '{print $1}')"
if [[ "$test_mode" != deferral ]]; then
  [[ "$state_hash_after" == "$state_hash_before" ]] || {
    echo "The isolated preferences/history file changed during the update." >&2
    exit 1
  }
fi
python3 - "$app_state_dir/state.json" "$test_mode" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    state = json.load(stream)
assert state["preferences"]["appearance"] == "Dark"
assert state["history"][0]["items"][0]["message"] == "preserve this local history entry"
if sys.argv[2] == "deferral":
    assert state["lastScan"] is not None
PY
if [[ -n "$installed_info_hash" ]]; then
  after_hash="$(shasum -a 256 "$installed_info" | awk '{print $1}')"
  after_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$installed_info")"
  [[ "$after_hash" == "$installed_info_hash" && "$after_version" == "$installed_version" ]] || {
    echo "/Applications/Sweepdeck.app changed during the isolated update test." >&2
    exit 1
  }
elif [[ "$installed_app_existed" != true && -e "/Applications/Sweepdeck.app" ]]; then
  echo "The isolated update created an unexpected /Applications/Sweepdeck.app copy." >&2
  exit 1
fi

swiftui_update_warnings="$(log show --last 10m --style compact --predicate "((processIdentifier == $old_pid) OR (processIdentifier == $current_pid)) AND (eventMessage CONTAINS 'Publishing changes from within view updates')" | sed '1d')"
if [[ -n "$swiftui_update_warnings" ]]; then
  echo "The isolated updater published Settings state during a SwiftUI view update:" >&2
  echo "$swiftui_update_warnings" >&2
  exit 1
fi

if [[ "$test_mode" == automatic || "$test_mode" == published ]]; then
  echo "PASS: Sparkle installed version $update_version on quit; the updated isolated app launched and passed validation."
else
  echo "PASS: Sparkle updated and relaunched the isolated app at version $update_version."
fi
if [[ "$test_mode" == deferral ]]; then
  echo "PASS: the scan result, seeded appearance/history, state marker, and installed app were preserved."
else
  echo "PASS: isolated appearance, history, state marker, and installed app were unchanged."
fi
echo "Test app for inspection: $old_app"
if [[ "$test_mode" == manual ]]; then
  echo "Check for Updates… once more in the relaunched app; the localhost feed is still running."
fi
wait_for_local_test_app_to_close
