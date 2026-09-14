#!/usr/bin/env bash
set -euo pipefail
TOOLS="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(pwd)"
if [[ ! -f "$APP_ROOT/pubspec.yaml" ]]; then
  echo "Run from your Flutter app root (pubspec.yaml not found in $APP_ROOT)." >&2
  exit 1
fi
(
  cd "$TOOLS"
  dart pub get >/dev/null
  dart run setup_bug_session.dart --project-dir "$APP_ROOT" "$@"
)
