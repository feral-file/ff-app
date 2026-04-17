#!/usr/bin/env bash
# Unit tests for fetch_latest_play_build_query.jq (no Play API calls).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="$ROOT/fetch_latest_play_build_query.jq"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required" >&2
  exit 1
fi

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $msg" >&2
    echo "Expected substring: $needle" >&2
    echo "Got: $haystack" >&2
    exit 1
  fi
}

# Internal track only; prior release 1.1.0 with versionCode 7 (API may return strings).
SAMPLE='{"tracks":[{"track":"internal","releases":[{"name":"1.1.0","status":"completed","versionCodes":["7"]}]}]}'

out=$(printf '%s' "$SAMPLE" | jq -r --arg targetVersion '1.1.1' -f "$JQ")
assert_contains "$out" "latest_version=1.1.1" "new versionName: output version is requested name"
assert_contains "$out" "latest_build_number=7" "new versionName: fallback to global max versionCode on internal"

out=$(printf '%s' "$SAMPLE" | jq -r --arg targetVersion '1.1.0' -f "$JQ")
assert_contains "$out" "latest_build_number=7" "existing versionName: max code for that release"

out=$(printf '%s' "$SAMPLE" | jq -r --arg targetVersion '' -f "$JQ")
assert_contains "$out" "latest_version=1.1.0" "empty targetVersion: latest_version from max-code release"
assert_contains "$out" "latest_build_number=7" "empty targetVersion: global max"

echo "ok fetch_latest_play_build_query"
