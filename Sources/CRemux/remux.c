#include "remux.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <limits.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

static void set_err(char *err, size_t err_len, const char *fmt, ...) {
    if (!err || err_len == 0) return;
    va_list args;
    va_start(args, fmt);
    vsnprintf(err, err_len, fmt, args);
    va_end(args);
}

// MP4 demands per-stream monotonic DTS, while real-world MKVs can start at a
// non-zero time or hand out slightly backwards stamps. Shift the first packet
// to zero and nudge regressive stamps forward — an invisible shift for a
// looping wallpaper, unlike a mux that refuses to write.
struct TsNormalizer {
    int64_t offset;
    int64_t last_dts;
    int64_t last_duration;
};

static void normalize_ts(struct TsNormalizer *n, AVPacket *pkt) {
    if (pkt->pts == AV_NOPTS_VALUE) pkt->pts = pkt->dts;
    if (pkt->dts == AV_NOPTS_VALUE) pkt->dts = pkt->pts;
    if (pkt->pts == AV_NOPTS_VALUE) pkt->pts = pkt->dts = 0;
    if (n->offset == INT64_MIN) n->offset = -FFMIN(pkt->pts, pkt->dts);
    pkt->pts += n->offset;
    pkt->dts += n->offset;
    if (n->last_dts != AV_NOPTS_VALUE && pkt->dts <= n->last_dts) {
        pkt->dts = n->last_dts + (n->last_duration > 0 ? n->last_duration : 1);
        if (pkt->pts < pkt->dts) pkt->pts = pkt->dts;
    }
    if (pkt->duration <= 0) pkt->duration = n->last_duration > 0 ? n->last_duration : 1;
    n->last_dts = pkt->dts;
    n->last_duration = pkt->duration;
}

int rill_remux(const char *src, const char *dst, char *err, size_t err_len) {
    if (err && err_len > 0) err[0] = '\0';
    av_log_set_level(AV_LOG_ERROR);

    AVFormatContext *in = NULL;
    AVFormatContext *out = NULL;
    AVPacket *pkt = av_packet_alloc();
    int ret = RILL_REMUX_FAILED;
    int wrote_header = 0;

    int avret = avformat_open_input(&in, src, NULL, NULL);
    if (avret < 0) {
        char detail[AV_ERROR_MAX_STRING_SIZE] = {0};
        av_strerror(avret, detail, sizeof detail);
        set_err(err, err_len, "open input: %s", detail);
        goto done;
    }
    if ((avret = avformat_find_stream_info(in, NULL)) < 0) {
        set_err(err, err_len, "read stream info: av error %d", avret);
        goto done;
    }

    // Pick the first real video track; Matroska files often carry the cover
    // art as an attached-picture video stream, which must not be selected.
    int video = -1;
    for (unsigned i = 0; i < in->nb_streams; i++) {
        const AVStream *s = in->streams[i];
        if (s->codecpar->codec_type != AVMEDIA_TYPE_VIDEO) continue;
        if (s->disposition & AV_DISPOSITION_ATTACHED_PIC) continue;
        if (s->codecpar->codec_id == AV_CODEC_ID_H264 ||
            s->codecpar->codec_id == AV_CODEC_ID_HEVC) {
            video = (int)i;
            break;
        }
    }
    if (video < 0) {
        for (unsigned i = 0; i < in->nb_streams; i++) {
            const AVStream *s = in->streams[i];
            if (s->codecpar->codec_type == AVMEDIA_TYPE_VIDEO &&
                !(s->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
                video = (int)i;
                break;
            }
        }
    }
    if (video < 0) {
        set_err(err, err_len, "no video stream");
        ret = RILL_REMUX_NO_VIDEO;
        goto done;
    }
    const AVCodecParameters *video_params = in->streams[video]->codecpar;
    if (video_params->codec_id != AV_CODEC_ID_H264 && video_params->codec_id != AV_CODEC_ID_HEVC) {
        set_err(err, err_len, "video codec %s cannot be copied into MP4",
                avcodec_get_name(video_params->codec_id));
        ret = RILL_REMUX_UNSUPPORTED_CODEC;
        goto done;
    }

    // Bring the first AAC track along when there is one; other audio codecs
    // would make AVFoundation reject the result, and wallpapers stay muted.
    int audio = -1;
    for (unsigned i = 0; i < in->nb_streams; i++) {
        const AVCodecParameters *p = in->streams[i]->codecpar;
        if (p->codec_type == AVMEDIA_TYPE_AUDIO && p->codec_id == AV_CODEC_ID_AAC) {
            audio = (int)i;
            break;
        }
    }

    // Name the muxer outright: the caller writes to a ".part" path whose
    // extension would defeat format guessing.
    if ((avret = avformat_alloc_output_context2(&out, NULL, "mp4", dst)) < 0) {
        set_err(err, err_len, "create output: av error %d", avret);
        goto done;
    }
    // moov up front so playback can start without first reading the file tail.
    if (out->priv_data &&
        av_opt_set(out->priv_data, "movflags", "+faststart", 0) < 0) {
        set_err(err, err_len, "faststart unavailable");
        goto done;
    }
    if (!(out->flags & AVFMT_NOFILE) && (avret = avio_open(&out->pb, dst, AVIO_FLAG_WRITE)) < 0) {
        char detail[AV_ERROR_MAX_STRING_SIZE] = {0};
        av_strerror(avret, detail, sizeof detail);
        set_err(err, err_len, "open output: %s", detail);
        goto done;
    }

    AVStream *video_out = avformat_new_stream(out, NULL);
    if (!video_out) {
        set_err(err, err_len, "new stream");
        goto done;
    }
    avret = avcodec_parameters_copy(video_out->codecpar, video_params);
    if (avret < 0) {
        set_err(err, err_len, "copy parameters: av error %d", avret);
        goto done;
    }
    // AVFoundation only accepts HEVC tagged hvc1; H.264 keeps the muxer default.
    if (video_params->codec_id == AV_CODEC_ID_HEVC)
        video_out->codecpar->codec_tag = MKTAG('h', 'v', 'c', '1');

    AVStream *audio_out = NULL;
    if (audio >= 0) {
        audio_out = avformat_new_stream(out, NULL);
        if (!audio_out) {
            set_err(err, err_len, "new stream");
            goto done;
        }
        avret = avcodec_parameters_copy(audio_out->codecpar, in->streams[audio]->codecpar);
        if (avret < 0) {
            set_err(err, err_len, "copy parameters: av error %d", avret);
            goto done;
        }
        audio_out->codecpar->codec_tag = 0;
    }

    if ((avret = avformat_write_header(out, NULL)) < 0) {
        set_err(err, err_len, "write header: av error %d", avret);
        goto done;
    }
    wrote_header = 1;

    struct TsNormalizer video_ts = {INT64_MIN, AV_NOPTS_VALUE, 0};
    struct TsNormalizer audio_ts = {INT64_MIN, AV_NOPTS_VALUE, 0};
    while ((avret = av_read_frame(in, pkt)) >= 0) {
        AVStream *target = NULL;
        struct TsNormalizer *ts = NULL;
        if (pkt->stream_index == video) {
            target = video_out;
            ts = &video_ts;
        } else if (audio >= 0 && pkt->stream_index == audio) {
            target = audio_out;
            ts = &audio_ts;
        } else {
            av_packet_unref(pkt);
            continue;
        }
        av_packet_rescale_ts(pkt, in->streams[pkt->stream_index]->time_base, target->time_base);
        normalize_ts(ts, pkt);
        pkt->stream_index = target->index;
        pkt->pos = -1;
        // Takes ownership of the packet's references; pkt is left blank.
        avret = av_interleaved_write_frame(out, pkt);
        if (avret < 0) {
            set_err(err, err_len, "write packet: av error %d", avret);
            goto done;
        }
    }
    if ((avret = av_write_trailer(out)) < 0) {
        set_err(err, err_len, "write trailer: av error %d", avret);
        goto done;
    }
    ret = RILL_REMUX_OK;

done:
    av_packet_free(&pkt);
    if (out) {
        if (wrote_header || out->pb) {
            if (!(out->flags & AVFMT_NOFILE)) avio_closep(&out->pb);
        }
        avformat_free_context(out);
    }
    avformat_close_input(&in);
    return ret;
}
