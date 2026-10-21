#!/bin/bash
# Runs unit tests at low priority. With only the Command Line Tools installed,
# Swift Testing lives outside SwiftPM's default framework and rpath search paths.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)"
ARGS=()
if [[ "$DEV" == *CommandLineTools* ]]; then
    FW="$DEV/Library/Developer/Frameworks"
    ARGS=(
        -Xswiftc -F -Xswiftc "$FW"
        -Xlinker -rpath -Xlinker "$FW"
        -Xlinker -rpath -Xlinker "$DEV/Library/Developer/usr/lib"
    )
fi

nice -n 19 swift test -j "${JOBS:-2}" ${ARGS[@]+"${ARGS[@]}"} "$@"
