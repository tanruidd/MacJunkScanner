#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-$ROOT_DIR/dist/MacJunkScanner.dmg}"
PROFILE="${NOTARY_PROFILE:-}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  echo "NOTARY_PROFILE is required. Create it first, for example:"
  echo '  xcrun notarytool store-credentials "macjunkscanner-notary" --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>" --password "<APP_SPECIFIC_PASSWORD>"'
  echo '  export NOTARY_PROFILE="macjunkscanner-notary"'
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"

echo "Notarized and stapled DMG:"
echo "$DMG_PATH"
