#!/bin/bash
# Builds Rill at low priority and assembles build/Rill.app (ad-hoc signed, sandboxed).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
JOBS="${JOBS:-2}"
APP="build/Rill.app"

nice -n 19 swift build -c "$CONFIG" -j "$JOBS" --product Rill
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Rill" "$APP/Contents/MacOS/Rill"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

if ! output=$(codesign --force --sign - --entitlements Resources/Rill.entitlements "$APP" 2>&1); then
    echo "$output" >&2
    exit 1
fi

echo "$APP"
