#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="MacJunkScanner.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT_DIR"
python3 "$ROOT_DIR/generate_icon.py"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/.build/release/MacJunkScanner" "$MACOS_DIR/MacJunkScanner"
cp "$ROOT_DIR/Assets/AppIcon-1024.png" "$RESOURCES_DIR/AppIcon.png"
chmod +x "$MACOS_DIR/MacJunkScanner"

echo "Built release app at:"
echo "$APP_DIR"
