#!/usr/bin/env bash
set -euo pipefail
TOOLS="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(pwd)"
if [[ ! -f "$ROOT/pubspec.yaml" ]]; then
  echo "Run from your Flutter app root (pubspec.yaml not found in $ROOT)." >&2
  exit 1
fi
dart "$TOOLS/generate_recorder_registry.dart" --project-dir "$ROOT" "$@"
