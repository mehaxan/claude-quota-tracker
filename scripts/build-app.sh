#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="BedrockMeter"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Built $APP_BUNDLE"
echo "Run it with: open \"$APP_BUNDLE\""
