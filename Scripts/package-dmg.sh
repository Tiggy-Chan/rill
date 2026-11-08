#!/bin/bash
# Packages Rill.app into a clean, drag-and-drop DMG installer.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Rill.app"
if [ ! -d "$APP" ]; then
    ./Scripts/build.sh
fi

VERSION="0.1.0"
DMG_NAME="Rill-$VERSION.dmg"
DMG_PATH="build/$DMG_NAME"
STAGE="build/dmg-staging"

echo "==> Preparing DMG staging area..."
rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE"

# 1. Copy Application bundle
cp -R "$APP" "$STAGE/Rill.app"

# 2. Add /Applications symlink for clean drag-and-drop install
ln -s /Applications "$STAGE/Applications"

echo "==> Creating compressed DMG image..."
hdiutil create \
    -volname "Rill $VERSION" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGE"
echo "==> Successfully created $DMG_PATH"
ls -lh "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
