#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/fetch_latest_play_build.sh <service-account-json> <package-name>

Example:
  scripts/fetch_latest_play_build.sh ~/Downloads/service-account.json com.feralfile.app
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SERVICE_ACCOUNT_JSON="$1"
PACKAGE_NAME="$2"
TOKEN_URL="https://oauth2.googleapis.com/token"
SCOPE="https://www.googleapis.com/auth/androidpublisher"

if [[ ! -f "$SERVICE_ACCOUNT_JSON" ]]; then
  echo "Error: service account file not found: $SERVICE_ACCOUNT_JSON" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PRIVATE_KEY_FILE="$TMP_DIR/private_key.pem"
CLIENT_EMAIL_VALUE="$(jq -r '.client_email // empty' "$SERVICE_ACCOUNT_JSON")"
jq -r '.private_key // empty' "$SERVICE_ACCOUNT_JSON" > "$PRIVATE_KEY_FILE"
if [[ -z "$CLIENT_EMAIL_VALUE" || ! -s "$PRIVATE_KEY_FILE" ]]; then
  echo "Error: service account JSON must include client_email and private_key" >&2
  exit 1
fi
NOW="$(date +%s)"
EXP="$((NOW + 3600))"

base64url() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

JWT_HEADER='{"alg":"RS256","typ":"JWT"}'
JWT_CLAIM="$(printf '{"iss":"%s","scope":"%s","aud":"%s","iat":%s,"exp":%s}' \
  "$CLIENT_EMAIL_VALUE" "$SCOPE" "$TOKEN_URL" "$NOW" "$EXP")"

HEADER_B64="$(printf '%s' "$JWT_HEADER" | base64url)"
CLAIM_B64="$(printf '%s' "$JWT_CLAIM" | base64url)"
UNSIGNED_TOKEN="$HEADER_B64.$CLAIM_B64"

SIGNATURE_B64="$(printf '%s' "$UNSIGNED_TOKEN" | openssl dgst -sha256 -sign "$PRIVATE_KEY_FILE" -binary | base64url)"
JWT_ASSERTION="$UNSIGNED_TOKEN.$SIGNATURE_B64"

TOKEN_RESPONSE="$(curl -sS -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=$JWT_ASSERTION")"

ACCESS_TOKEN="$(printf '%s' "$TOKEN_RESPONSE" | jq -r '.access_token // empty')"
if [[ -z "$ACCESS_TOKEN" ]]; then
  AUTH_ERROR="$(printf '%s' "$TOKEN_RESPONSE" | jq -r '.error_description // .error // "unknown auth error"')"
  echo "Failed to get OAuth token: $AUTH_ERROR" >&2
  exit 1
fi

BASE_URL="https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$PACKAGE_NAME"

EDIT_RESPONSE="$(curl -sS -X POST "$BASE_URL/edits" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{}')"

EDIT_ID="$(printf '%s' "$EDIT_RESPONSE" | jq -r '.id // empty')"
if [[ -z "$EDIT_ID" ]]; then
  EDIT_ERROR="$(printf '%s' "$EDIT_RESPONSE" | jq -r '.error.message // "unknown edits.insert error"')"
  echo "Failed to create edit: $EDIT_ERROR" >&2
  exit 1
fi

TRACKS_RESPONSE="$(curl -sS "$BASE_URL/edits/$EDIT_ID/tracks" \
  -H "Authorization: Bearer $ACCESS_TOKEN")"

# best-effort cleanup of edit; ignore failure
curl -sS -X DELETE "$BASE_URL/edits/$EDIT_ID" -H "Authorization: Bearer $ACCESS_TOKEN" >/dev/null 2>&1 || true

printf '%s' "$TRACKS_RESPONSE" | jq -r '
  [
    (.tracks // [])[] as $t
    | ($t.releases // [])[] as $r
    | ($r.versionCodes // [])[]? as $vc
    | {
        code: ($vc | tonumber?),
        track: ($t.track // ""),
        name: ($r.name // ""),
        status: ($r.status // "")
      }
  ]
  | map(select(.code != null))
  | if length == 0 then
      "latest_version_code=0\nlatest_track=\nlatest_release_name=\nlatest_release_status="
    else
      (max_by(.code) | "latest_version_code=\(.code)\nlatest_track=\(.track)\nlatest_release_name=\(.name)\nlatest_release_status=\(.status)")
    end
'
