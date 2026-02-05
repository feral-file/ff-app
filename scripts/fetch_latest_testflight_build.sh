#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/fetch_latest_testflight_build.sh <bundle-id> [version] [issuer-id] [key-id] [private-key-path]

Examples:
  scripts/fetch_latest_testflight_build.sh com.feralfile.app 1.2.3
  scripts/fetch_latest_testflight_build.sh com.feralfile.app 1.2.3 "$FF_TESTFLIGHT_ISSUER_ID" "$FF_TESTFLIGHT_KEY_ID" ~/Downloads/AuthKey_TN89262HMB.p8
  scripts/fetch_latest_testflight_build.sh com.feralfile.app

Environment fallback:
  APPSTORE_CONNECT_ISSUER_ID
  APPSTORE_CONNECT_KEY_ID
  APPSTORE_CONNECT_PRIVATE_KEY_PATH (defaults to ~/Downloads/AuthKey_TN89262HMB.p8)
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

BUNDLE_ID="$1"
APP_VERSION="${2:-}"
ISSUER_ID="${3:-${APPSTORE_CONNECT_ISSUER_ID:-}}"
KEY_ID="${4:-${APPSTORE_CONNECT_KEY_ID:-}}"
PRIVATE_KEY_PATH="${5:-${APPSTORE_CONNECT_PRIVATE_KEY_PATH:-$HOME/Downloads/AuthKey_TN89262HMB.p8}}"

if [[ -z "$ISSUER_ID" ]]; then
  echo "Error: issuer-id is required (arg #3 or APPSTORE_CONNECT_ISSUER_ID)" >&2
  exit 1
fi

if [[ -z "$KEY_ID" ]]; then
  echo "Error: key-id is required (arg #4 or APPSTORE_CONNECT_KEY_ID)" >&2
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
  echo "Error: private key file not found: $PRIVATE_KEY_PATH" >&2
  exit 1
fi

for cmd in curl jq openssl xxd; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required" >&2
    exit 1
  fi
done

base64url() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

der_to_jose() {
  local der_file="$1"
  local hex idx tag seq_len int_len r_hex s_hex parsed_len

  hex="$(xxd -p -c 4096 "$der_file" | tr -d '\n')"
  idx=0

  parse_len() {
    local first n len_hex
    first="${hex:$idx:2}"
    idx=$((idx + 2))
    if (( 16#$first < 128 )); then
      parsed_len="$((16#$first))"
      return
    fi
    n=$((16#$first - 128))
    len_hex="${hex:$idx:$((n * 2))}"
    idx=$((idx + n * 2))
    parsed_len="$((16#$len_hex))"
  }

  tag="${hex:$idx:2}"
  idx=$((idx + 2))
  if [[ "$tag" != "30" ]]; then
    echo "Error: invalid ECDSA DER signature (missing sequence tag)" >&2
    exit 1
  fi
  parse_len
  seq_len="$parsed_len"
  if (( seq_len <= 0 )); then
    echo "Error: invalid ECDSA DER signature (invalid sequence length)" >&2
    exit 1
  fi

  tag="${hex:$idx:2}"
  idx=$((idx + 2))
  if [[ "$tag" != "02" ]]; then
    echo "Error: invalid ECDSA DER signature (missing r integer tag)" >&2
    exit 1
  fi
  parse_len
  int_len="$parsed_len"
  r_hex="${hex:$idx:$((int_len * 2))}"
  idx=$((idx + int_len * 2))

  tag="${hex:$idx:2}"
  idx=$((idx + 2))
  if [[ "$tag" != "02" ]]; then
    echo "Error: invalid ECDSA DER signature (missing s integer tag)" >&2
    exit 1
  fi
  parse_len
  int_len="$parsed_len"
  s_hex="${hex:$idx:$((int_len * 2))}"

  while (( ${#r_hex} > 64 )) && [[ "${r_hex:0:2}" == "00" ]]; do
    r_hex="${r_hex:2}"
  done
  while (( ${#s_hex} > 64 )) && [[ "${s_hex:0:2}" == "00" ]]; do
    s_hex="${s_hex:2}"
  done

  while (( ${#r_hex} < 64 )); do r_hex="0$r_hex"; done
  while (( ${#s_hex} < 64 )); do s_hex="0$s_hex"; done

  if (( ${#r_hex} != 64 || ${#s_hex} != 64 )); then
    echo "Error: invalid ECDSA DER signature component size" >&2
    exit 1
  fi

  printf '%s%s' "$r_hex" "$s_hex" | xxd -r -p | base64url
}

JWT_HEADER="$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$KEY_ID")"
NOW="$(date +%s)"
EXP="$((NOW + 1200))"
JWT_PAYLOAD="$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"appstoreconnect-v1"}' "$ISSUER_ID" "$NOW" "$EXP")"

HEADER_B64="$(printf '%s' "$JWT_HEADER" | base64url)"
PAYLOAD_B64="$(printf '%s' "$JWT_PAYLOAD" | base64url)"
UNSIGNED_TOKEN="$HEADER_B64.$PAYLOAD_B64"
TMP_DER_SIG="$(mktemp)"
trap 'rm -f "$TMP_DER_SIG"' EXIT
printf '%s' "$UNSIGNED_TOKEN" | openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" -binary > "$TMP_DER_SIG"
SIGNATURE_B64="$(der_to_jose "$TMP_DER_SIG")"
JWT_TOKEN="$UNSIGNED_TOKEN.$SIGNATURE_B64"

ASC_API_BASE="https://api.appstoreconnect.apple.com/v1"

asc_get() {
  curl -sS --get "$1" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    "${@:2}"
}

extract_error() {
  printf '%s' "$1" | jq -r '.errors[0].detail // .errors[0].title // empty'
}

APP_RESPONSE="$(asc_get "$ASC_API_BASE/apps" --data-urlencode "filter[bundleId]=$BUNDLE_ID" --data-urlencode "limit=1")"
APP_ERROR="$(extract_error "$APP_RESPONSE")"
if [[ -n "$APP_ERROR" ]]; then
  echo "Failed to query apps: $APP_ERROR" >&2
  exit 1
fi

APP_ID="$(printf '%s' "$APP_RESPONSE" | jq -r '.data[0].id // empty')"
if [[ -z "$APP_ID" ]]; then
  echo "Failed to find app for bundle id: $BUNDLE_ID" >&2
  exit 1
fi

if [[ -n "$APP_VERSION" ]]; then
  PR_RESPONSE="$(asc_get "$ASC_API_BASE/preReleaseVersions" --data-urlencode "filter[app]=$APP_ID" --data-urlencode "filter[version]=$APP_VERSION" --data-urlencode "limit=200")"
  PR_ERROR="$(extract_error "$PR_RESPONSE")"
  if [[ -n "$PR_ERROR" ]]; then
    echo "Failed to query pre-release versions: $PR_ERROR" >&2
    exit 1
  fi

  PR_IDS_CSV="$(printf '%s' "$PR_RESPONSE" | jq -r '[.data[]?.id] | join(",")')"
  if [[ -z "$PR_IDS_CSV" ]]; then
    echo "latest_version=$APP_VERSION"
    echo "latest_build_number=0"
    exit 0
  fi

  BUILDS_RESPONSE="$(asc_get "$ASC_API_BASE/builds" --data-urlencode "filter[app]=$APP_ID" --data-urlencode "filter[preReleaseVersion]=$PR_IDS_CSV" --data-urlencode "sort=-uploadedDate" --data-urlencode "limit=1" --data-urlencode "fields[builds]=version,uploadedDate")"
  LATEST_BUILD="$(printf '%s' "$BUILDS_RESPONSE" | jq -r '.data[0].attributes.version // "0"')"
  if [[ -z "$LATEST_BUILD" || "$LATEST_BUILD" == "null" ]]; then
    LATEST_BUILD="0"
  fi

  echo "latest_version=$APP_VERSION"
  echo "latest_build_number=$LATEST_BUILD"
  exit 0
fi

BUILDS_RESPONSE="$(asc_get "$ASC_API_BASE/builds" --data-urlencode "filter[app]=$APP_ID" --data-urlencode "sort=-uploadedDate" --data-urlencode "limit=1" --data-urlencode "include=preReleaseVersion" --data-urlencode "fields[builds]=version,uploadedDate" --data-urlencode "fields[preReleaseVersions]=version")"
BUILDS_ERROR="$(extract_error "$BUILDS_RESPONSE")"
if [[ -n "$BUILDS_ERROR" ]]; then
  echo "Failed to query builds: $BUILDS_ERROR" >&2
  exit 1
fi

LATEST_BUILD="$(printf '%s' "$BUILDS_RESPONSE" | jq -r '.data[0].attributes.version // "0"')"
if [[ -z "$LATEST_BUILD" || "$LATEST_BUILD" == "null" ]]; then
  LATEST_BUILD="0"
fi

LATEST_VERSION="$(printf '%s' "$BUILDS_RESPONSE" | jq -r '.included[]? | select(.type=="preReleaseVersions") | .attributes.version // empty' | head -n 1)"
if [[ -z "$LATEST_VERSION" ]]; then
  LATEST_VERSION="0"
fi

echo "latest_version=$LATEST_VERSION"
echo "latest_build_number=$LATEST_BUILD"
