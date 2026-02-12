#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

TEST_TARGET="test/unit"
OUTPUT_MD="coverage/business_layer_unit_coverage.md"
METRICS_TSV="coverage/business_layer_unit_coverage.metrics.tsv"
BASELINE_TSV="coverage/business_layer_unit_coverage.baseline.tsv"
UPDATE_BASELINE=0

usage() {
  cat <<USAGE
Usage: scripts/report_business_coverage.sh [options]

Options:
  --test-target <path>   Test target passed to 'flutter test' (default: test/unit)
  --output <path>        Markdown output path (default: coverage/business_layer_unit_coverage.md)
  --metrics <path>       Machine-readable metrics TSV path
                         (default: coverage/business_layer_unit_coverage.metrics.tsv)
  --baseline <path>      Baseline TSV for non-degradation checks
                         (default: coverage/business_layer_unit_coverage.baseline.tsv)
  --update-baseline      Replace baseline TSV with current metrics
  -h, --help             Show this help message
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-target)
      TEST_TARGET="$2"
      shift 2
      ;;
    --output)
      OUTPUT_MD="$2"
      shift 2
      ;;
    --metrics)
      METRICS_TSV="$2"
      shift 2
      ;;
    --baseline)
      BASELINE_TSV="$2"
      shift 2
      ;;
    --update-baseline)
      UPDATE_BASELINE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$OUTPUT_MD")"
mkdir -p "$(dirname "$METRICS_TSV")"
mkdir -p "$(dirname "$BASELINE_TSV")"

printf 'Running unit coverage with: flutter test %s --coverage\n' "$TEST_TARGET"
flutter test "$TEST_TARGET" --coverage >/dev/null

LCOV_FILE="coverage/lcov.info"
if [[ ! -f "$LCOV_FILE" ]]; then
  echo "Missing coverage file: $LCOV_FILE" >&2
  exit 1
fi

tmp_metrics="$(mktemp)"
tmp_modules="$(mktemp)"
tmp_files="$(mktemp)"
trap 'rm -f "$tmp_metrics" "$tmp_modules" "$tmp_files"' EXIT

awk '
function percent(h, f) {
  if (f == 0) return 0;
  return (100.0 * h) / f;
}
function normalize(path) {
  gsub(/\\/, "/", path);
  return path;
}
function business_file(path,   n, p, i) {
  n = split(path, p, "/");
  for (i = 1; i < n; i++) {
    if (p[i] == "lib" && (p[i + 1] == "app" || p[i + 1] == "domain" || p[i + 1] == "infra")) {
      module = p[i + 1];
      rel = p[i];
      for (j = i + 1; j <= n; j++) rel = rel "/" p[j];
      if (rel ~ /\.g\.dart$/) return "";
      return rel;
    }
  }
  return "";
}
BEGIN {
  OFS = "\t";
}
/^SF:/ {
  sf = normalize(substr($0, 4));
  file = business_file(sf);
  active = (file != "");
}
/^DA:/ && active {
  split(substr($0, 4), da_fields, ",");
  line_hits = da_fields[2] + 0;
  lf[file] += 1;
  module_lf[module] += 1;
  total_lf += 1;
  if (line_hits > 0) {
    lh[file] += 1;
    module_lh[module] += 1;
    total_lh += 1;
  }
}
END {
  printf("scope\tname\tlh\tlf\tpct\n");
  printf("overall\tall\t%d\t%d\t%.2f\n", total_lh, total_lf, percent(total_lh, total_lf));

  for (m in module_lf) {
    printf("module\t%s\t%d\t%d\t%.2f\n", m, module_lh[m], module_lf[m], percent(module_lh[m], module_lf[m]));
  }

  for (f in lf) {
    split(f, path_parts, "/");
    printf("file\t%s\t%d\t%d\t%.2f\n", f, lh[f], lf[f], percent(lh[f], lf[f]));
  }
}
' "$LCOV_FILE" > "$tmp_metrics"

if [[ ! -s "$tmp_metrics" ]]; then
  echo "Unable to parse coverage metrics from $LCOV_FILE" >&2
  exit 1
fi

cp "$tmp_metrics" "$METRICS_TSV"

if [[ "$UPDATE_BASELINE" -eq 1 ]]; then
  cp "$METRICS_TSV" "$BASELINE_TSV"
  echo "Updated baseline: $BASELINE_TSV"
fi

# Non-degradation check against baseline (overall + module scopes).
if [[ -f "$BASELINE_TSV" && "$UPDATE_BASELINE" -eq 0 ]]; then
  awk -F '\t' '
  NR == FNR {
    if (FNR == 1) next;
    key = $1 FS $2;
    base[key] = $5 + 0;
    next;
  }
  FNR == 1 { next; }
  {
    if ($1 != "overall" && $1 != "module") next;
    key = $1 FS $2;
    current = $5 + 0;
    if ((key in base) && current + 0.0001 < base[key]) {
      printf("Coverage regression for %s: baseline %.2f%%, current %.2f%%\n", key, base[key], current) > "/dev/stderr";
      failed = 1;
    }
  }
  END {
    if (failed) exit 2;
  }
  ' "$BASELINE_TSV" "$METRICS_TSV"
fi

awk -F '\t' '$1=="module" { print $0 }' "$METRICS_TSV" | sort -t $'\t' -k5,5n > "$tmp_modules"
awk -F '\t' '$1=="file" { print $0 }' "$METRICS_TSV" | sort -t $'\t' -k2,2 > "$tmp_files"

overall_row="$(awk -F '\t' '$1=="overall" { print $0; exit }' "$METRICS_TSV")"
if [[ -z "$overall_row" ]]; then
  echo "Missing overall metric row" >&2
  exit 1
fi

overall_lh="$(echo "$overall_row" | awk -F '\t' '{print $3}')"
overall_lf="$(echo "$overall_row" | awk -F '\t' '{print $4}')"
overall_pct="$(echo "$overall_row" | awk -F '\t' '{print $5}')"

now_utc="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

{
  echo "# Business Layer Unit Test Coverage Report"
  echo
  echo "Generated: $now_utc"
  echo
  echo "## Scope"
  echo
  printf -- "- Test target: \`%s\`\n" "$TEST_TARGET"
  echo "- Measured layers: \`lib/app\`, \`lib/domain\`, \`lib/infra\`"
  echo "- Tooling: \`flutter test --coverage\` (LCOV parser)"
  echo
  echo "## Overall"
  echo
  echo "| Metric | Covered Lines | Total Lines | Coverage |"
  echo "| --- | ---: | ---: | ---: |"
  printf "| Business layers (unit) | %s | %s | %.2f%% |\n" "$overall_lh" "$overall_lf" "$overall_pct"
  echo
  echo "## Module Coverage"
  echo
  echo "| Module | Covered Lines | Total Lines | Coverage |"
  echo "| --- | ---: | ---: | ---: |"

  while IFS=$'\t' read -r scope name lh lf pct; do
    printf "| %s | %s | %s | %.2f%% |\n" "$name" "$lh" "$lf" "$pct"
  done < "$tmp_modules"

  echo
  echo "## File Coverage"
  echo
  echo "| File | Covered Lines | Total Lines | Coverage |"
  echo "| --- | ---: | ---: | ---: |"

  while IFS=$'\t' read -r scope name lh lf pct; do
    printf "| %s | %s | %s | %.2f%% |\n" "$name" "$lh" "$lf" "$pct"
  done < "$tmp_files"

  echo
  echo "## Notes"
  echo
  echo "- This report estimates coverage using line coverage from LCOV generated by Flutter tests."
  echo "- Only files under business layers are included; UI/rendering folders are intentionally excluded."
  if [[ -f "$BASELINE_TSV" ]]; then
    printf -- "- Baseline regression check source: \`%s\`.\n" "$BASELINE_TSV"
  fi
} > "$OUTPUT_MD"

printf 'Coverage Markdown report: %s\n' "$OUTPUT_MD"
printf 'Coverage metrics TSV: %s\n' "$METRICS_TSV"
