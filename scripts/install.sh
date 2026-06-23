#!/usr/bin/env bash
set -euo pipefail

# Builds FocusSlot and installs it into /Applications, then relaunches it.
# Run after making changes:  ./scripts/install.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="FocusSlot"
SRC_APP="dist/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"

echo "==> Building $APP_NAME"
./scripts/build-app.sh

echo "==> Quitting running $APP_NAME (if any)"
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
# Fall back to a hard kill if it ignored the quit.
pkill -x "$APP_NAME" 2>/dev/null || true
# Give the process a moment to release the bundle before we overwrite it.
for _ in 1 2 3 4 5; do
  pgrep -x "$APP_NAME" >/dev/null 2>&1 || break
  sleep 0.3
done

echo "==> Installing to $DEST_APP"
rm -rf "$DEST_APP"
cp -R "$SRC_APP" "$DEST_APP"

echo "==> Launching $APP_NAME"
open "$DEST_APP"

echo "Installed and launched $DEST_APP"
echo "Tip: if 'Open at Login' was on, it stays registered at this path."
