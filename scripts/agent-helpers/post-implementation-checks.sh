#!/usr/bin/env bash

set -euo pipefail

##
# Post-implementation checks for agent: auto-format changed files, lint, and test.
# Outputs compact markdown suitable for LLM processing.
# Default scope is changed Dart files compared to a git ref.
#
# Usage:
#   scripts/agent-helpers/post-implementation-checks.sh [OPTIONS] [git-ref]
#
# Options:
#   --dir DIR      Check all files in this directory (lib/infra, lib/app, etc.)
#   --all          Skip git diff filtering; check all files in --dir (or all .dart files if no --dir)
#   --skip-tests   Skip flutter test and run only fix + lint checks
#   --lint-only    Alias for --skip-tests
#
# Args:
#   git-ref        Compare changed files to this ref (default: HEAD)
#                  Ignored if --all is used
#
# Environment variables (optional):
#   DART_FIX_CONCURRENCY         Parallel processes for dart fix (default: 8)
#   FLUTTER_ANALYZE_CONCURRENCY  Parallel processes for flutter analyze (default: 8)
#   FLUTTER_TEST_CONCURRENCY     Parallel test files (default: 4)
#
# Output:
#   Markdown report with:
#   - Auto-formatted files (via dart fix)
#   - Lint errors/warnings/infos from flutter analyze and optional custom_lint
#   - Failed tests (file)
#
# Examples:
#   scripts/agent-helpers/post-implementation-checks.sh
#   scripts/agent-helpers/post-implementation-checks.sh --lint-only
#   scripts/agent-helpers/post-implementation-checks.sh --dir lib/infra --all
#   DART_FIX_CONCURRENCY=16 scripts/agent-helpers/post-implementation-checks.sh --dir lib/app
#   scripts/agent-helpers/post-implementation-checks.sh main
##

check_dir=""
skip_git_filter=false
skip_tests=false
git_ref="HEAD"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      check_dir="$2"
      shift 2
      ;;
    --all)
      skip_git_filter=true
      shift
      ;;
    --skip-tests|--lint-only)
      skip_tests=true
      shift
      ;;
    *)
      git_ref="$1"
      shift
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# Ensure dependencies (including dart_code_linter) are resolved before analyze
flutter pub get > /dev/null 2>&1 || true

# Concurrency settings (can be overridden via environment)
# Default: 8 for file operations, 4 for tests (to avoid resource contention)
DART_FIX_CONCURRENCY="${DART_FIX_CONCURRENCY:-8}"
FLUTTER_ANALYZE_CONCURRENCY="${FLUTTER_ANALYZE_CONCURRENCY:-8}"
FLUTTER_TEST_CONCURRENCY="${FLUTTER_TEST_CONCURRENCY:-4}"

# Temp files
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

changed_files_list="$tmp_dir/changed_files.txt"
fixed_files_list="$tmp_dir/fixed_files.txt"
lint_report="$tmp_dir/lint_report.txt"
custom_lint_report="$tmp_dir/custom_lint_report.txt"
test_report="$tmp_dir/test_report.txt"
status_summary="$tmp_dir/status_summary.txt"

##
# 1. Get list of .dart files to check
##
if [[ "$skip_git_filter" == true ]]; then
  # Check all files in the directory (exclude generated .g.dart)
  if [[ -n "$check_dir" ]]; then
    find "$check_dir" -type f -name '*.dart' ! -name '*.g.dart' | sort > "$changed_files_list"
  else
    find . -type f -name '*.dart' ! -name '*.g.dart' | sort > "$changed_files_list"
  fi
  filter_mode="all files"
else
  # Check only changed files (exclude generated .g.dart)
  if [[ -n "$check_dir" ]]; then
    git diff --name-only "$git_ref" -- "$check_dir/*.dart" | grep -v '\.g\.dart$' > "$changed_files_list" || true
  else
    git diff --name-only "$git_ref" -- '*.dart' | grep -v '\.g\.dart$' > "$changed_files_list" || true
  fi
  filter_mode="changed files (compared to \`$git_ref\`)"
fi

if [[ ! -s "$changed_files_list" ]]; then
  echo "## Post-Implementation Checks"
  echo ""
  echo "No Dart files found ($filter_mode)."
  exit 0
fi

changed_count=$(wc -l < "$changed_files_list")

##
# 2. Run dart fix first so lint reflects the final on-disk state.
##
: > "$fixed_files_list"
: > "$lint_report"
: > "$custom_lint_report"
: > "$status_summary"

# Function to process single file for dart fix
process_dart_fix() {
  local file="$1"
  local fixed_list="$2"
  
  if [[ -z "$file" ]]; then
    return
  fi
  
  # Capture file mtime before
  before_mtime=$(stat -f%m "$file" 2>/dev/null || echo "0")
  
  # Run dart fix for this file
  dart fix --apply "$file" > /dev/null 2>&1 || true
  
  # Capture file mtime after
  after_mtime=$(stat -f%m "$file" 2>/dev/null || echo "0")
  
  # If mtime changed, it was fixed
  if [[ "$after_mtime" != "$before_mtime" ]]; then
    echo "$file" >> "$fixed_list"
  fi
}

# Function to run flutter analyze on a single file
process_analyze() {
  local file="$1"
  local lint_out="$2"
  
  if [[ -z "$file" ]]; then
    return
  fi
  
  # Run flutter analyze
  analyze_output=$(flutter analyze "$file" 2>&1 || true)
  
  # Extract lint issues: info • msg • path/file.dart:10:5 • code
  lint_lines=$(echo "$analyze_output" | grep -E "• .* • .*:[0-9]+:[0-9]+ • " || true)
  
  if [[ -z "$lint_lines" ]]; then
    return
  fi
  
  # Write to temp file first to avoid concurrent writes
  temp_lint="/tmp/lint_$RANDOM_$$.txt"
  {
    echo "### $file"
    echo ""
    
    # BSD `cut -d` requires a single-byte delimiter and fails on the Unicode
    # bullet used by `flutter analyze` output. Parse using Python for
    # cross-platform correctness.
    python3 -c $'import re, sys\nfor raw in sys.stdin:\n  line = raw.strip()\n  if not line:\n    continue\n  parts = [p.strip() for p in line.split(\"•\")]\n  if len(parts) < 3:\n    continue\n  message = parts[1] if len(parts) > 1 else \"\"\n  location = parts[2] if len(parts) > 2 else \"\"\n  m = re.search(r\":(\\d+:\\d+)\\b\", location)\n  lineinfo = m.group(1) if m else \"\"\n  print(f\"- {lineinfo} - {message}\".rstrip())' <<<"$lint_lines"
    
    echo ""
  } >> "$temp_lint"
  
  cat "$temp_lint" >> "$lint_out"
  rm -f "$temp_lint"
}

export -f process_dart_fix process_analyze

# Run dart fix first so follow-up lint matches the code that would be committed.
echo "Running dart fix..." >&2
echo "  dart fix concurrency: $DART_FIX_CONCURRENCY files" >&2

cat "$changed_files_list" | xargs -P "$DART_FIX_CONCURRENCY" -I {} bash -c 'process_dart_fix "$@"' _ {} "$fixed_files_list"

##
# 3. Run lint checks against the post-fix state.
##
echo "Running flutter analyze..." >&2
echo "  flutter analyze concurrency: $FLUTTER_ANALYZE_CONCURRENCY files" >&2

cat "$changed_files_list" | xargs -P "$FLUTTER_ANALYZE_CONCURRENCY" -I {} bash -c 'process_analyze "$@"' _ {} "$lint_report"

custom_lint_available=false
if [[ -f "custom_lint.yaml" ]] && grep -q "custom_lint" "pubspec.yaml"; then
  custom_lint_available=true
fi

if [[ "$custom_lint_available" == true ]]; then
  echo "Running custom_lint..." >&2
  while IFS= read -r file; do
    if [[ -z "$file" ]] || [[ "$file" == *.g.dart ]]; then
      continue
    fi

    custom_lint_output="$(dart run custom_lint "$file" 2>&1 || true)"
    custom_lint_lines="$(echo "$custom_lint_output" | grep -E "^[[:space:]]*[^[:space:]].*:[0-9]+:[0-9]+.*•.*•" || true)"

    if [[ -z "$custom_lint_lines" ]]; then
      continue
    fi

    {
      echo "### $file"
      echo ""
      # custom_lint output is not stable across versions: some builds include a
      # trailing severity token while others stop at `file:line:col • msg • rule`.
      # Accept both shapes so local checks do not silently miss CI-visible issues.
      python3 -c $'import re, sys\nfor raw in sys.stdin:\n  line = raw.rstrip(\"\\n\")\n  if not line.strip():\n    continue\n  parts = [p.strip() for p in line.split(\"•\")]\n  if len(parts) < 3:\n    continue\n  location = parts[0]\n  message = parts[1]\n  rule_name = parts[2]\n  severity = parts[3] if len(parts) > 3 else None\n  match = re.search(r\":(\\d+):(\\d+)\\b\", location)\n  if not match:\n    continue\n  line_no, col_no = match.groups()\n  suffix = f\" ({rule_name}, {severity})\" if severity else f\" ({rule_name})\"\n  print(f\"- {line_no}:{col_no} - {message}{suffix}\")' <<<"$custom_lint_lines"
      echo ""
    } >> "$custom_lint_report"
  done < "$changed_files_list"
fi

##
# 4. Run flutter test with parallel test execution unless explicitly skipped.
##
: > "$test_report"

if [[ "$skip_tests" == false ]]; then
  echo "Running flutter test (concurrency: $FLUTTER_TEST_CONCURRENCY)..." >&2
  test_output=$(flutter test --concurrency="$FLUTTER_TEST_CONCURRENCY" 2>&1 || true)

  # Check if there are failures
  if echo "$test_output" | grep -E "(FAILED|EXCEPTION|ERROR)" > /dev/null; then
    # Extract test files/test names with failures
    # Format: "✗ Some test description (test/some_test.dart:123)"
    # We want: "test/some_test.dart - Some test description"
    echo "$test_output" | grep -E "✗ " | while read -r line; do
      # Extract test name and file
      test_name=$(echo "$line" | sed 's/✗ //;s/ (test\/.*//')
      test_file=$(echo "$line" | sed -E 's/.*\(test\/(.*\.dart).*/test\/\1/' || echo "")
      
      if [[ -n "$test_file" ]] && [[ "$test_file" != "test/" ]]; then
        echo "- $test_file - $test_name" >> "$test_report"
      fi
    done || true
  fi
fi

overall_exit_code=0

# The helper is a verification gate, not just a reporter. Keep the markdown
# output for review loops, but fail the command whenever lint or tests found
# actionable issues so reruns are authoritative like CI.
if [[ -s "$lint_report" ]]; then
  echo "lint" >> "$status_summary"
  overall_exit_code=1
fi

if [[ -s "$custom_lint_report" ]]; then
  echo "custom_lint" >> "$status_summary"
  overall_exit_code=1
fi

if [[ -s "$test_report" ]]; then
  echo "test" >> "$status_summary"
  overall_exit_code=1
fi

##
# 5. Generate markdown report
##
{
  echo "## Post-Implementation Checks"
  echo ""
  echo "- Checked files: $changed_count"
  if [[ -n "$check_dir" ]]; then
    echo "- Directory: \`$check_dir\`"
  fi
  if [[ "$skip_git_filter" == false ]]; then
    echo "- Compared to: \`$git_ref\`"
  else
    echo "- Mode: all files (git filtering disabled)"
  fi
  if [[ "$skip_tests" == true ]]; then
    echo "- Tests: skipped (\`--skip-tests\` / \`--lint-only\`)"
  else
    echo "- Tests: enabled"
  fi
  echo ""
  
  # Auto-fixed files section
  if [[ -s "$fixed_files_list" ]]; then
    echo "### Auto-Fixed (via \`dart fix\`)"
    echo ""
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        echo "- \`$file\`"
      fi
    done < "$fixed_files_list"
    echo ""
  fi
  
  # Lint report
  if [[ -s "$lint_report" ]]; then
    echo "### Lint Issues"
    echo ""
    cat "$lint_report"
  else
    echo "### Lint Issues"
    echo ""
    echo "None found."
    echo ""
  fi

  if [[ "$custom_lint_available" == true ]]; then
    if [[ -s "$custom_lint_report" ]]; then
      echo "### Custom Lint Issues"
      echo ""
      cat "$custom_lint_report"
    else
      echo "### Custom Lint Issues"
      echo ""
      echo "None found."
      echo ""
    fi
  fi
  
  # Test report
  if [[ "$skip_tests" == true ]]; then
    echo "### Test Failures"
    echo ""
    echo "Skipped."
    echo ""
  elif [[ -s "$test_report" ]]; then
    echo "### Test Failures"
    echo ""
    cat "$test_report"
    echo ""
  else
    echo "### Test Failures"
    echo ""
    echo "None."
    echo ""
  fi
  
} | tee "$tmp_dir/final_report.md"

# Also write to file in project root for reference
cp "$tmp_dir/final_report.md" "$repo_root/.post-implementation-checks-report.md"

if [[ "$overall_exit_code" -ne 0 ]]; then
  echo "Post-implementation checks failed: $(paste -sd ', ' "$status_summary")" >&2
fi

exit "$overall_exit_code"
