#!/usr/bin/env bash
set -euo pipefail

# Generates Resources/FocusSlot.icns (and a 1024 PNG preview) from
# scripts/generate-icon.swift. Run after tweaking the icon design.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PNG="$WORK/icon_1024.png"
ICONSET="$WORK/FocusSlot.iconset"
mkdir -p "$ICONSET"

echo "==> Rendering 1024 master"
swift scripts/generate-icon.swift "$PNG"

echo "==> Generating iconset sizes"
sips -z 16 16     "$PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$PNG"                       "$ICONSET/icon_512x512@2x.png"

echo "==> Building icns"
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/FocusSlot.icns
cp "$PNG" Resources/AppIcon-preview.png

echo "Wrote Resources/FocusSlot.icns and Resources/AppIcon-preview.png"
