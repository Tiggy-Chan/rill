#!/bin/bash
# Regenerates Resources/AppIcon.icns from Scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

nice -n 19 swiftc -O Scripts/make-icon.swift -o "$WORK/make-icon"
"$WORK/make-icon" "$WORK/icon_1024.png"

SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon_1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$WORK/icon_1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo Resources/AppIcon.icns
