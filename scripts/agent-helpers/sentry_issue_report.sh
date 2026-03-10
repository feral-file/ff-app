#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/agent-helpers/sentry_issue_report.sh \
    --org-name <organization_name> \
    --project-id <project_id> \
    --issue-id <issue_id> \
    [--token <sentry_auth_token>] \
    [--base-url <sentry_base_url>] \
    [--max-frames <n>] \
    [--max-breadcrumbs <n>]

Reference:
  https://docs.sentry.io/api/requests/

Environment fallback:
  SENTRY_TOKEN (preferred)
  SENTRY_AUTH_TOKEN
  SENTRY_PROJECT_ID
  SENTRY_ORG_NAME
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
}

normalize_org_name() {
  local input="$1"
  printf '%s' "$input" | tr '[:upper:]_' '[:lower:]-'
}

extract_message() {
  local issue_json="$1"
  local event_json="$2"

  local message
  message="$(jq -r '
    [
      $event.title,
      $event.message,
      $event.logentry.formatted,
      $issue.title,
      $issue.culprit
    ]
    | map(select(type == "string" and length > 0))
    | .[0] // "Unavailable"
  ' --argjson issue "$issue_json" --argjson event "$event_json" -n)"

  printf '%s' "$message"
}

extract_device_os() {
  local event_json="$1"

  jq -r '
    .contexts.os as $os
    | if ($os | type) != "object" then
        "Unavailable"
      else
        [
          ($os.name // ""),
          ($os.version // ""),
          (if (($os.build // "") | length) > 0 then "build \($os.build)" else "" end)
        ]
        | map(select(length > 0))
        | if length == 0 then "Unavailable" else join(" ") end
      end
  ' <<<"$event_json"
}

extract_stacktrace_lines() {
  local event_json="$1"
  local max_frames="$2"

  jq -r '
    (
      .entries
      | map(select(.type == "exception"))
      | .[0].data.values[0].stacktrace.frames
    ) as $frames
    | if ($frames | type) != "array" or ($frames | length) == 0 then
        empty
      else
        (
          if (($frames | map(select(.inApp == true)) | length) > 0) then
            ($frames | map(select(.inApp == true)))
          else
            $frames
          end
        )
        | .[-$max_frames:]
        | .[]
        | "- `\((.function // "<anonymous>")) (\((.filename // .absPath // "?")):\((.lineno // "?")))`"
      end
  ' --argjson max_frames "$max_frames" <<<"$event_json"
}

extract_breadcrumb_lines() {
  local event_json="$1"
  local max_breadcrumbs="$2"

  jq -r '
    def is_signal:
      ((.level // "") | ascii_downcase) as $lvl
      | ($lvl == "fatal" or $lvl == "error" or $lvl == "warning");
    def is_non_debug:
      ((.level // "") | ascii_downcase) != "debug";
    def is_not_filtered:
      ((.message // "") != "[Filtered]");

    (
      .entries
      | map(select(.type == "breadcrumbs"))
      | .[0].data.values
    ) as $crumbs
    | if ($crumbs | type) != "array" or ($crumbs | length) == 0 then
        empty
      else
        (
          if (($crumbs | map(select(is_signal)) | length) > 0) then
            ($crumbs | map(select(is_signal and is_not_filtered)))
          elif (($crumbs | map(select(is_non_debug)) | length) > 0) then
            ($crumbs | map(select(is_non_debug and is_not_filtered)))
          else
            $crumbs
          end
        )
        | .[-$max_breadcrumbs:]
        | .[]
        | "- \((.timestamp // "unknown-time")) [\((.level // "info"))/\((.category // "uncategorized"))] \((.message // ""))"
      end
  ' --argjson max_breadcrumbs "$max_breadcrumbs" <<<"$event_json"
}

api_get() {
  local url="$1"
  local body
  local http_code

  body="$(mktemp)"
  http_code="$(curl -sS -o "$body" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Accept: application/json' \
    "$url")"

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    local error_content
    error_content="$(cat "$body")"
    rm -f "$body"
    echo "Error: Sentry API request failed ($http_code) for $url" >&2
    if [[ -n "$error_content" ]]; then
      echo "Response: $error_content" >&2
    fi
    exit 1
  fi

  cat "$body"
  rm -f "$body"
}

ORG_NAME=""
PROJECT_ID=""
ISSUE_ID=""
TOKEN="${SENTRY_TOKEN:-${SENTRY_AUTH_TOKEN:-}}"
OUTPUT_PATH=""
BASE_URL="https://sentry.io"
MAX_FRAMES=12
MAX_BREADCRUMBS=8

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org-name)
      ORG_NAME="${2:-}"
      shift 2
      ;;
    --project-id)
      PROJECT_ID="${2:-}"
      shift 2
      ;;
    --issue-id)
      ISSUE_ID="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --base-url)
      BASE_URL="${2:-}"
      shift 2
      ;;
    --max-frames)
      MAX_FRAMES="${2:-}"
      shift 2
      ;;
    --max-breadcrumbs)
      MAX_BREADCRUMBS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ORG_NAME" ]]; then
  ORG_NAME="${SENTRY_ORG_NAME:-}"
fi

if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="${SENTRY_PROJECT_ID:-}"
fi

if [[ -z "$TOKEN" ]]; then
  TOKEN="${SENTRY_TOKEN:-${SENTRY_AUTH_TOKEN:-}}"
fi

if [[ -z "$ORG_NAME" || -z "$PROJECT_ID" || -z "$ISSUE_ID" ]]; then
  echo 'Error: org name, project id, and issue id are required.' >&2
  echo 'Provide flags (--org-name, --project-id, --issue-id) or env vars (SENTRY_ORG_NAME, SENTRY_PROJECT_ID) with --issue-id.' >&2
  usage
  exit 1
fi

if [[ -z "$TOKEN" ]]; then
  echo 'Error: missing Sentry token (use --token, SENTRY_TOKEN, or SENTRY_AUTH_TOKEN).' >&2
  exit 1
fi

require_cmd curl
require_cmd jq

ORG_SLUG="$(normalize_org_name "$ORG_NAME")"

PROJECTS_JSON="$(api_get "$BASE_URL/api/0/projects/")"
MATCHED_PROJECT="$(jq -c --arg org "$ORG_SLUG" --arg project "$PROJECT_ID" '
  [
    .[]
    | select(
        ((.slug // "") == $project or (.id // "") == $project)
        and ((.organization.slug // "") == $org)
      )
  ]
  | .[0] // empty
' <<<"$PROJECTS_JSON")"

if [[ -z "$MATCHED_PROJECT" ]]; then
  echo "Error: project '$PROJECT_ID' not found under organization '$ORG_SLUG'." >&2
  exit 1
fi

if [[ "$ISSUE_ID" =~ ^[0-9]+$ ]]; then
  ISSUE_JSON="$(api_get "$BASE_URL/api/0/issues/$ISSUE_ID/")"
  ISSUE_NUMERIC_ID="$ISSUE_ID"
else
  SHORTID_JSON="$(api_get "$BASE_URL/api/0/organizations/$ORG_SLUG/shortids/$ISSUE_ID/")"
  ISSUE_NUMERIC_ID="$(jq -r '.groupId // empty' <<<"$SHORTID_JSON")"
  ISSUE_JSON="$(jq -c '.group // empty' <<<"$SHORTID_JSON")"

  if [[ -z "$ISSUE_NUMERIC_ID" || -z "$ISSUE_JSON" ]]; then
    echo "Error: unable to resolve short issue id '$ISSUE_ID'." >&2
    exit 1
  fi
fi

LATEST_EVENT_JSON="$(api_get "$BASE_URL/api/0/issues/$ISSUE_NUMERIC_ID/events/latest/")"

MESSAGE="$(extract_message "$ISSUE_JSON" "$LATEST_EVENT_JSON")"
DEVICE_OS="$(extract_device_os "$LATEST_EVENT_JSON")"
STACKTRACE_LINES="$(
  extract_stacktrace_lines "$LATEST_EVENT_JSON" "$MAX_FRAMES" || true
)"
BREADCRUMB_LINES="$(
  extract_breadcrumb_lines "$LATEST_EVENT_JSON" "$MAX_BREADCRUMBS" || true
)"

{
  echo '# Sentry Debug Context'
  echo
  echo '## Message'
  echo
  echo "$MESSAGE"
  echo
  echo '## Device OS'
  echo
  echo "$DEVICE_OS"
  echo
  echo '## Stacktrace'
  echo

  if [[ -n "$STACKTRACE_LINES" ]]; then
    echo "$STACKTRACE_LINES"
  else
    echo '- No stacktrace frames available'
  fi

  echo
  echo '## Breadcrumbs (High Signal)'
  echo

  if [[ -n "$BREADCRUMB_LINES" ]]; then
    echo "$BREADCRUMB_LINES"
  else
    echo '- No breadcrumbs available'
  fi
}
