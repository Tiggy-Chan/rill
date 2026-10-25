#!/bin/bash
# Builds the minimal LGPL FFmpeg libraries bundled with Rill: only the
# demuxers for containers AVFoundation cannot open (Matroska/WebM, AVI, FLV),
# the MP4 muxer and the file protocol. Converting is stream copy only, so no
# decoders are built in. Result: Vendor/ffmpeg/{include,lib,BUILD-NOTES.md}.
# Safe to re-run; pass a local tarball path to skip the download.
#
# LGPL: the libraries are linked dynamically and the exact source, checksum
# and configure flags are recorded in Vendor/ffmpeg/BUILD-NOTES.md.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$REPO_ROOT"

VERSION="7.1.1"
SHA256="733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1"
TARBALL="ffmpeg-$VERSION.tar.xz"
URL="https://ffmpeg.org/releases/$TARBALL"
DIST="Vendor/dist"
SRC="$DIST/ffmpeg-$VERSION"
PREFIX="$REPO_ROOT/Vendor/ffmpeg"

if [ "${1:-}" != "" ]; then
    if [ ! -f "$1" ]; then
        echo "no such tarball: $1" >&2
        exit 1
    fi
    mkdir -p "$DIST"
    cp "$1" "$DIST/$TARBALL"
elif [ ! -f "$DIST/$TARBALL" ]; then
    mkdir -p "$DIST"
    curl -L --max-time 300 -o "$DIST/$TARBALL.part" "$URL"
    mv "$DIST/$TARBALL.part" "$DIST/$TARBALL"
fi

ACTUAL="$(shasum -a 256 "$DIST/$TARBALL" | cut -d' ' -f1)"
if [ "$ACTUAL" != "$SHA256" ]; then
    echo "sha256 mismatch for $TARBALL" >&2
    echo "  expected $SHA256" >&2
    echo "  got      $ACTUAL" >&2
    exit 1
fi

if [ ! -d "$SRC" ]; then
    tar -xJf "$DIST/$TARBALL" -C "$DIST"
fi

cd "$SRC"
FLAGS=(
    --prefix="$PREFIX"
    --disable-programs --disable-doc --disable-network --disable-autodetect
    --disable-everything
    --enable-demuxer=matroska,avi,flv
    --enable-muxer=mp4
    --enable-protocol=file
    --enable-zlib
    --enable-shared --disable-static
)
rm -rf "$PREFIX"
nice -n 19 ./configure "${FLAGS[@]}"
nice -n 19 make -j"${JOBS:-2}"
nice -n 19 make install
cp COPYING.LGPLv2.1 "$PREFIX/"

# Keep only the three libraries Rill links, under their major-versioned
# names, and load them through @rpath so the app can carry the dylibs in
# Contents/Frameworks. The build installs absolute install names plus a set
# of stub libraries a --disable-everything build still produces.
cd "$PREFIX/lib"
for NAME in libavutil libavcodec libavformat; do
    REAL="$(find . -maxdepth 1 -type f -name "$NAME.*.*.*.dylib" | head -1)"
    MAJOR="$(basename "$REAL" | sed -E "s|^$NAME\.([0-9]+)\..*dylib$|\1|")"
    mv "$REAL" "$NAME.$MAJOR.dylib"
done
find . -maxdepth 1 -name '*.dylib' \
    ! -name 'libavutil.[0-9]*.dylib' \
    ! -name 'libavcodec.[0-9]*.dylib' \
    ! -name 'libavformat.[0-9]*.dylib' -delete
for NAME in libavutil libavcodec libavformat; do
    ln -s "$(ls "$NAME".[0-9]*.dylib)" "$NAME.dylib"
done
for DYLIB in libavutil.[0-9]*.dylib libavcodec.[0-9]*.dylib libavformat.[0-9]*.dylib; do
    install_name_tool -id "@rpath/$DYLIB" "$DYLIB"
    for DEP in $(otool -L "$DYLIB" | awk '$1 ~ /\/lib(avutil|avcodec|avformat)\.[0-9]+\.dylib$/ {print $1}'); do
        install_name_tool -change "$DEP" "@rpath/$(basename "$DEP")" "$DYLIB"
    done
done

cat > "$PREFIX/BUILD-NOTES.md" <<EOF
# FFmpeg build bundled with Rill

- Source: $URL
- Version: $VERSION
- sha256: $SHA256
- Configure flags: ${FLAGS[*]}
- License: LGPLv2.1 or later (default configure; no --enable-gpl options).
  Linked dynamically; see COPYING.LGPLv2.1 in the FFmpeg source tree.
- Rebuilt by: Scripts/fetch-ffmpeg.sh
EOF

echo "$PREFIX"
