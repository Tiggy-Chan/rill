#ifndef CREMUX_REMUX_H
#define CREMUX_REMUX_H

#include <stddef.h>

// Outcome of a container conversion.
enum {
    RILL_REMUX_OK = 0,
    RILL_REMUX_NO_VIDEO,          // the file holds no video stream at all
    RILL_REMUX_UNSUPPORTED_CODEC, // video codec is neither H.264 nor HEVC; name in err
    RILL_REMUX_FAILED             // open/read/write failure; message in err
};

// Copies the video stream (and the first AAC audio stream, when present) from
// src into a fresh MP4 file at dst without re-encoding, tagging HEVC as hvc1
// so AVFoundation accepts it. dst is overwritten. Returns one of the
// RILL_REMUX_* codes; on failure err receives a short ASCII message.
int rill_remux(const char *src, const char *dst, char *err, size_t err_len);

#endif
