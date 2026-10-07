#!/bin/bash
# Regenerates Resources/AppIcon.icns from scripts/generate-icon.swift.
# Run this after changing the icon design; the .icns is committed, this isn't run at app build time.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

MASTER="$WORK_DIR/icon-master.png"
ICONSET="$WORK_DIR/AppIcon.iconset"

swift scripts/generate-icon.swift "$MASTER"

mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$MASTER" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$MASTER" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns

echo "Wrote Resources/AppIcon.icns"
