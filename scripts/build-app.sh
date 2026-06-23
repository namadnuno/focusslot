#!/usr/bin/env bash
set -euo pipefail

swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR=".build/release/FocusSlot.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/FocusSlot" "$APP_DIR/Contents/MacOS/FocusSlot"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Built $APP_DIR"
