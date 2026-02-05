#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/fetch_latest_play_build.sh <service-account-json> <package-name> [version]

Example:
  scripts/fetch_latest_play_build.sh ~/Downloads/service-account.json com.feralfile.app
  scripts/fetch_latest_play_build.sh ~/Downloads/service-account.json com.feralfile.app 1.0.8
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
TARGET_VERSION="${3:-}"
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

printf '%s' "$TRACKS_RESPONSE" | jq -r --arg targetVersion "$TARGET_VERSION" '
  def to_release_entries($track):
    [
      (($track.releases // [])[]? | {
        version: (.name // ""),
        status: (.status // ""),
        track: ($track.track // ""),
        codes: [(.versionCodes // [])[]? | tonumber?] | map(select(. != null))
      })
      | .max_code = (if (.codes | length) == 0 then null else (.codes | max) end)
    ];

  def to_code_entries($releases):
    [
      $releases[] as $r
      | $r.codes[]? as $c
      | {
          code: $c,
          track: $r.track,
          version: $r.version,
          status: $r.status
        }
    ];

  (
    (.tracks // []) | map(select(.track == "internal")) | .[0]
  ) as $internal_track
  | if $internal_track == null then
      "latest_version=0\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
    else
      (to_release_entries($internal_track)) as $releases
      | if ($targetVersion | length) > 0 then
          (to_code_entries($releases | map(select(.version == $targetVersion)))) as $entries
          | if ($entries | length) == 0 then
              "latest_version=\($targetVersion)\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
            else
              ($entries | max_by(.code)) as $latest
              | "latest_version=\($targetVersion)\nlatest_build_number=\($latest.code)\nlatest_version_code=\($latest.code)\nlatest_track=\($latest.track)\nlatest_release_status=\($latest.status)"
            end
        else
          ($releases | map(select(.max_code != null))) as $with_codes
          | if ($with_codes | length) == 0 then
              "latest_version=0\nlatest_build_number=0\nlatest_version_code=0\nlatest_track=internal\nlatest_release_status="
            else
              ($with_codes | max_by(.max_code)) as $latest_release
              | "latest_version=\(if ($latest_release.version | length) > 0 then $latest_release.version else "0" end)\nlatest_build_number=\($latest_release.max_code)\nlatest_version_code=\($latest_release.max_code)\nlatest_track=\($latest_release.track)\nlatest_release_status=\($latest_release.status)"
            end
        end
    end
'
