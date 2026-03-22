#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/MacJunkScanner.app"
DMG_PATH="$ROOT_DIR/dist/MacJunkScanner.dmg"

"$ROOT_DIR/scripts/build_release_app.sh"
"$ROOT_DIR/scripts/sign_app.sh" "$APP_PATH"
"$ROOT_DIR/scripts/package_dmg.sh" "$APP_PATH" "$DMG_PATH"
"$ROOT_DIR/scripts/notarize_dmg.sh" "$DMG_PATH"
"$ROOT_DIR/scripts/verify_distribution.sh" "$APP_PATH"

echo ""
echo "Release artifacts ready:"
echo "  $APP_PATH"
echo "  $DMG_PATH"
