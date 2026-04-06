#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -f .env ]]; then
  echo "Note: .env not found. Copy .env.example to .env before running the app."
  echo "The checks below still validate the default public contributor setup."
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter test test/unit/infra/services/release_notes_service_test.dart"
flutter test test/unit/infra/services/release_notes_service_test.dart

echo "Local setup verification passed."
