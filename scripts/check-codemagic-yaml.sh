#!/usr/bin/env bash
# Validates apps/mobile/codemagic.yaml is structurally well-formed and that
# the critical Android-release wiring is present (tag trigger, keystore
# signing, Play internal track upload). Designed to run with no external
# dependency beyond bash + grep + python3 stdlib so it works on a clean CI
# runner and on the dev's laptop.
#
# This is a *contract* test, not a YAML schema validator: it asserts the
# specific lines we rely on. If you intentionally restructure codemagic.yaml,
# update the assertions here in the same commit.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
YAML="$ROOT/apps/mobile/codemagic.yaml"

if [ ! -f "$YAML" ]; then
  echo "MISSING: $YAML" >&2
  exit 1
fi

# Cheap YAML well-formedness check: indentation must use spaces only, no tabs.
# Use ANSI-C string for tab so this works on both BSD grep (macOS) and GNU grep.
if grep -n "$(printf '\t')" "$YAML" >/dev/null; then
  echo "FAIL: $YAML contains tabs (YAML requires spaces)." >&2
  grep -n "$(printf '\t')" "$YAML" >&2
  exit 1
fi

fail=0
require_grep() {
  local pattern="$1" msg="$2"
  if ! grep -qE "$pattern" "$YAML"; then
    echo "FAIL: $msg (missing pattern: $pattern)" >&2
    fail=1
  fi
}

require_grep '^workflows:' \
  "top-level 'workflows:' key"
require_grep '^[[:space:]]+android-release:' \
  "workflow 'android-release' must be defined"
require_grep '^[[:space:]]+- tag$' \
  "android-release must trigger on 'tag' events"
require_grep "pattern: 'v\\*'" \
  "android-release must include tag_patterns matching 'v*'"
require_grep '^[[:space:]]+- android_keystore$' \
  "environment.groups must include 'android_keystore'"
require_grep '^[[:space:]]+- google_play$' \
  "environment.groups must include 'google_play'"
require_grep 'KEYSTORE_FILE' \
  "must consume the KEYSTORE_FILE secret to materialize the keystore"
require_grep 'key.properties' \
  "must write key.properties for Gradle signing"
require_grep 'flutter build appbundle --release' \
  "must build a signed AAB for Play upload"
require_grep 'flutter build apk --release' \
  "must build a signed APK for internal distribution"
require_grep '^[[:space:]]+google_play:' \
  "publishing.google_play block required"
require_grep "track: internal" \
  "publishing.google_play.track must be 'internal'"
require_grep 'GCLOUD_SERVICE_ACCOUNT_CREDENTIALS' \
  "publishing.google_play.credentials must reference GCLOUD_SERVICE_ACCOUNT_CREDENTIALS"

if [ "$fail" -ne 0 ]; then
  echo "codemagic.yaml validation FAILED" >&2
  exit 1
fi

echo "OK $YAML"
