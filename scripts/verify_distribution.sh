#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/MacJunkScanner.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

echo "codesign verification"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo ""
echo "Gatekeeper assessment"
spctl --assess --type execute --verbose=4 "$APP_PATH"
