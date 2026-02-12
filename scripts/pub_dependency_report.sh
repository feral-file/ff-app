#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/pub_dependency_report.sh <package_name> [output_markdown_path]

Examples:
  scripts/pub_dependency_report.sh riverpod
  scripts/pub_dependency_report.sh flutter_riverpod /tmp/flutter_riverpod.md

Environment:
  MAX_SECTION_LINES   Max lines for README/EXAMPLE/CHANGELOG snippets (default: 250)
                      Use 0 for no truncation.

Notes:
  - Uses pub.dev API endpoints documented at https://pub.dev/help/api
  - Writes Markdown to stdout by default, or to output_markdown_path when provided.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "" ]]; then
  usage
  exit 0
fi

package_name="$1"
output_path="${2:-}"
max_lines="${MAX_SECTION_LINES:-250}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required." >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "Error: tar is required." >&2
  exit 1
fi

line_matches_package_name() {
  local pubspec="$1"
  local pattern="^[[:space:]]*name:[[:space:]]*${package_name}[[:space:]]*$"
  if command -v rg >/dev/null 2>&1; then
    rg -q "$pattern" "$pubspec"
  else
    grep -Eq "$pattern" "$pubspec"
  fi
}

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

api_package_url="https://pub.dev/api/packages/${package_name}"
package_json="$tmp_dir/package.json"

curl -fsSL "$api_package_url" -o "$package_json"

latest_archive_url="$(python3 - "$package_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
print(data["latest"]["archive_url"])
PY
)"

latest_tar="$tmp_dir/latest.tar.gz"
curl -fsSL "$latest_archive_url" -o "$latest_tar"

extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"
tar -xzf "$latest_tar" -C "$extract_dir"

package_root="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
package_root="${package_root:-$extract_dir}"

matched_pubspec="$(
  first_any=""
  first_non_example=""
  while read -r pubspec; do
    if ! line_matches_package_name "$pubspec"; then
      continue
    fi
    if [[ -z "$first_any" ]]; then
      first_any="$pubspec"
    fi
    if [[ "$pubspec" != *"/example/"* && -z "$first_non_example" ]]; then
      first_non_example="$pubspec"
      break
    fi
  done < <(find "$extract_dir" -type f -name 'pubspec.yaml')

  if [[ -n "$first_non_example" ]]; then
    echo "$first_non_example"
  else
    echo "$first_any"
  fi
)"
if [[ -n "${matched_pubspec:-}" ]]; then
  package_root="$(dirname "$matched_pubspec")"
fi

find_file_case_insensitive() {
  local root="$1"
  local pattern="$2"
  find "$root" -type f -iname "$pattern" | head -n 1
}

readme_file="$(find "$package_root" -maxdepth 1 -type f -iname 'README*' | head -n 1)"
if [[ -z "${readme_file:-}" ]]; then
  readme_file="$(find_file_case_insensitive "$package_root" 'README*')"
fi

changelog_file="$(find "$package_root" -maxdepth 1 -type f -iname 'CHANGELOG*' | head -n 1)"
if [[ -z "${changelog_file:-}" ]]; then
  changelog_file="$(find_file_case_insensitive "$package_root" 'CHANGELOG*')"
fi

example_file="$(
  {
    find "$package_root" -type f -path '*/example/main.dart' | head -n 1
    find "$package_root" -type f -path '*/example/*.dart' \
      ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.mocks.dart' | head -n 1
    find "$package_root" -type f -path '*/example/*' -iname 'README*' | head -n 1
    find "$package_root" -type f -path '*/example/*' | head -n 1
  } | sed '/^$/d' | head -n 1
)"

readme_file="${readme_file:-}"
changelog_file="${changelog_file:-}"
example_file="${example_file:-}"

python3 - "$package_json" "$package_name" "$max_lines" "$readme_file" "$changelog_file" "$example_file" > "$tmp_dir/report.md" <<'PY'
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Optional, Tuple, Dict

package_json_path = Path(sys.argv[1])
package_name = sys.argv[2]
max_lines = int(sys.argv[3])
readme_file = Path(sys.argv[4]) if sys.argv[4] else None
changelog_file = Path(sys.argv[5]) if sys.argv[5] else None
example_file = Path(sys.argv[6]) if sys.argv[6] else None

with package_json_path.open("r", encoding="utf-8") as f:
    data = json.load(f)

latest = data["latest"]
latest_version = latest["version"]
latest_published = latest.get("published", "unknown")
latest_pubspec = latest.get("pubspec", {})
repository = latest_pubspec.get("repository", "").strip()
homepage = latest_pubspec.get("homepage", "").strip()
github_url = repository if "github.com" in repository.lower() else (
    homepage if "github.com" in homepage.lower() else ""
)
project_url = repository or homepage or f"https://pub.dev/packages/{package_name}"

versions = data.get("versions", [])

stable_versions = []
for item in versions:
    version = item.get("version", "")
    if "-" in version:
        continue
    stable_versions.append({
        "version": version,
        "published": item.get("published", "unknown"),
    })

last_five = stable_versions[-5:] if len(stable_versions) >= 5 else stable_versions
last_five = list(reversed(last_five))

def read_text(path: Optional[Path]) -> str:
    if path is None or not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""

def clip_lines(text: str, limit: int) -> Tuple[str, bool]:
    lines = text.splitlines()
    if limit <= 0 or len(lines) <= limit:
        return text.strip(), False
    return "\n".join(lines[:limit]).strip(), True

def find_version_sections(changelog_text: str) -> Dict[str, str]:
    sections = {}
    if not changelog_text.strip():
        return sections

    lines = changelog_text.splitlines()
    heading_pattern = re.compile(r"^\s{0,3}#{1,6}\s*\[?v?(\d+\.\d+\.\d+(?:[.+-][^\]\s]+)?)\]?")

    current_version = None
    buffer = []

    def flush():
        nonlocal buffer, current_version
        if current_version and current_version not in sections:
            sections[current_version] = "\n".join(buffer).strip()

    for line in lines:
        m = heading_pattern.match(line)
        if m:
            flush()
            current_version = m.group(1)
            buffer = []
            continue
        if current_version is not None:
            buffer.append(line)
    flush()
    return sections

readme_text = read_text(readme_file)
changelog_text = read_text(changelog_file)
example_text = read_text(example_file)

readme_body, readme_truncated = clip_lines(readme_text, max_lines)
example_body, example_truncated = clip_lines(example_text, max_lines)
_, _ = clip_lines(changelog_text, max_lines)
changelog_sections = find_version_sections(changelog_text)

now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()

print(f"# Pub Dependency Report: `{package_name}`")
print()
print(f"- Generated (UTC): `{now}`")
print("- API docs: https://pub.dev/help/api")
print(f"- Package API endpoint: https://pub.dev/api/packages/{package_name}")
print()
print("## Latest Version")
print()
print(f"- Version: `{latest_version}`")
print(f"- Published: `{latest_published}`")
print(f"- Recommended `pubspec.yaml` constraint: `^{latest_version}`")
print(f"- Package URL: {project_url}")
print(f"- GitHub URL: {github_url or 'not found in pubspec metadata'}")
print()
print("## Last 5 Stable Versions and Changelogs")
print()
for item in last_five:
    version = item["version"]
    published = item["published"]
    changelog_url = f"https://pub.dev/packages/{package_name}/versions/{version}/changelog"
    print(f"### `{version}`")
    print(f"- Published: `{published}`")
    print(f"- Changelog URL: {changelog_url}")

    section = changelog_sections.get(version, "").strip()
    if section:
        clipped, truncated = clip_lines(section, max_lines)
        print("- Changelog excerpt:")
        print("```markdown")
        print(clipped)
        print("```")
        if truncated:
            print(f"- Note: excerpt truncated to {max_lines} lines.")
    else:
        print("- Changelog excerpt: not found in extracted CHANGELOG file.")
    print()

print("## README (Latest)")
print()
if readme_body:
    print("```markdown")
    print(readme_body)
    print("```")
    if readme_truncated:
        print(f"- Note: README truncated to {max_lines} lines.")
else:
    print("README not found in latest package archive.")
print()

print("## Example (Latest)")
print()
if example_body:
    print("```dart")
    print(example_body)
    print("```")
    if example_truncated:
        print(f"- Note: example truncated to {max_lines} lines.")
    print(f"- Extracted from: `{example_file}`")
else:
    print("Example file not found in latest package archive.")
print()

print("## Guidance For Dependency Updates")
print()
print(f"1. Use latest stable by default: `^{latest_version}`.")
print("2. If dependency solving fails, inspect the changelog entries above from newest to oldest.")
print("3. Choose the newest version that resolves conflicts, then validate with `flutter pub get` and tests.")
print("4. Prefer usage patterns from README and example above; consult GitHub when behavior is unclear.")
PY

if [[ -n "$output_path" ]]; then
  cp "$tmp_dir/report.md" "$output_path"
  echo "Report written to $output_path"
else
  cat "$tmp_dir/report.md"
fi
