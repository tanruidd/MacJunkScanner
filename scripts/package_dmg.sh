#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="${1:-$DIST_DIR/MacJunkScanner.app}"
DMG_PATH="${2:-$DIST_DIR/MacJunkScanner.dmg}"
VOLUME_NAME="${VOLUME_NAME:-Mac Junk Scanner}"
TMP_DIR="$DIST_DIR/.dmg-staging"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

rm -rf "$TMP_DIR" "$DMG_PATH"
mkdir -p "$TMP_DIR"
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$TMP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$TMP_DIR"

echo "Packaged DMG:"
echo "$DMG_PATH"
