#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/MacJunkScanner.app}"
IDENTITY="${SIGNING_IDENTITY:-}"

if [[ -z "$IDENTITY" ]]; then
  echo "SIGNING_IDENTITY is required. Example:"
  echo '  export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"'
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

codesign \
  --force \
  --timestamp \
  --options runtime \
  --sign "$IDENTITY" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Signed app:"
echo "$APP_PATH"
