#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "frontend/node_modules" ]; then
  (cd frontend && npm ci)
fi

(cd frontend && npm run build)

swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="dist/FocusSlot.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/FocusSlot" "$APP_DIR/Contents/MacOS/FocusSlot"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "frontend/dist" "$APP_DIR/Contents/Resources/frontend"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
