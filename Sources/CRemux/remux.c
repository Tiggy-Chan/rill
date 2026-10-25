#include "remux.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static void set_err(char *err, size_t err_len, const char *fmt, ...) {
    if (!err || err_len == 0) return;
    va_list args;
    va_start(args, fmt);
    vsnprintf(err, err_len, fmt, args);
    va_end(args);
}

// Leading video packets held back until the reorder depth can be measured.
#define WINDOW 64

// Matroska stores presentation times only: packets arrive in decode order
// with b-frame PTS out of order, and the MP4 muxer wants a monotonic DTS per
// sample. DTS values are synthesized the way encoders make them: the DTS of
// the packet in video slot k is the PTS of the frame shown `delay` display
// positions earlier, i.e. the (k-delay)-th smallest PTS seen. The pipeline
// below collects PTS values in arrival order; whenever more than `delay`
// values are pending, the smallest one is the DTS for the slot that arrived
// `delay` packets ago. Slots before the first measured value extrapolate
// backwards by the frame duration; everything is then shifted so playback
// starts at zero (the same delay an encoder writes as an edit list).
struct VideoPipeline {
    int64_t *sorted; // pending PTS values, ascending
    int size;
    int capacity;
    int delay;
    int64_t delta; // frame duration estimate, in the video timebase
    int64_t shift; // added to every raw timestamp at emit time
    int released;  // DTS values handed out so far
    int64_t last_dts;
};

struct AudioClock {
    int64_t shift; // the video shift, expressed in the audio timebase
    int64_t last_dts;
    int64_t last_duration;
};

struct HeldPacket {
    AVPacket *pkt;
    int is_video;
    int video_slot;  // index of this packet among video packets, or -1
    int64_t dts;     // raw pipeline DTS; AV_NOPTS_VALUE while pending
};

static void pipeline_init(struct VideoPipeline *p, int delay, int64_t delta) {
    p->capacity = delay + 8;
    p->sorted = av_malloc_array(p->capacity, sizeof *p->sorted);
    p->size = 0;
    p->delay = delay;
    p->delta = delta;
    p->shift = 0;
    p->released = 0;
    p->last_dts = AV_NOPTS_VALUE;
}

static void pipeline_free(struct VideoPipeline *p) {
    av_freep(&p->sorted);
}

static void pipeline_feed_pts(struct VideoPipeline *p, int64_t pts) {
    if (p->size == p->capacity) {
        p->capacity *= 2;
        int64_t *grown = av_realloc_array(p->sorted, p->capacity, sizeof *p->sorted);
        if (!grown) return;
        p->sorted = grown;
    }
    int64_t value = pts == AV_NOPTS_VALUE ? 0 : pts;
    int i = p->size;
    while (i > 0 && p->sorted[i - 1] > value) {
        p->sorted[i] = p->sorted[i - 1];
        i--;
    }
    p->sorted[i] = value;
    p->size++;
}

static int pipeline_slot_ready(const struct VideoPipeline *p) {
    return p->size > p->delay;
}

static int64_t pipeline_pop_min(struct VideoPipeline *p) {
    int64_t min = p->sorted[0];
    for (int i = 1; i < p->size; i++) p->sorted[i - 1] = p->sorted[i];
    p->size--;
    return min;
}

// Hands one released DTS value to the video slot it belongs to (slot number
// `released + delay`), extrapolating the pre-roll slots on the first release.
static void pipeline_assign(struct VideoPipeline *p, int64_t value,
                            struct HeldPacket *held, int held_count) {
    if (p->released == 0) {
        p->shift = (int64_t)p->delay * p->delta - value;
        for (int i = 0; i < held_count; i++) {
            if (held[i].is_video && held[i].video_slot < p->delay) {
                held[i].dts = value - (int64_t)(p->delay - held[i].video_slot) * p->delta;
            }
        }
    }
    int target = p->released + p->delay;
    for (int i = held_count - 1; i >= 0; i--) {
        if (held[i].is_video && held[i].video_slot == target) {
            held[i].dts = value;
            break;
        }
    }
    p->released++;
}

// Reorder depth and frame duration from the leading video PTS window: a frame
// decoded at slot k but displayed at rank r reveals k - r frames of reorder,
// and the median gap between sorted PTS values is the frame duration.
static void measure_window(const int64_t *pts, int n, int *delay_out, int64_t *delta_out) {
    int64_t sorted[WINDOW];
    for (int i = 0; i < n; i++) sorted[i] = pts[i];
    for (int i = 1; i < n; i++) {
        int64_t key = sorted[i];
        int j = i - 1;
        while (j >= 0 && sorted[j] > key) {
            sorted[j + 1] = sorted[j];
            j--;
        }
        sorted[j + 1] = key;
    }
    int delay = 0;
    for (int i = 0; i < n; i++) {
        int rank = 0;
        while (rank < n && sorted[rank] < pts[i]) rank++;
        if (i - rank > delay) delay = i - rank;
    }
    *delay_out = delay;
    int64_t diffs[WINDOW];
    int nd = 0;
    for (int i = 1; i < n; i++) {
        if (sorted[i] > sorted[i - 1]) diffs[nd++] = sorted[i] - sorted[i - 1];
    }
    for (int i = 1; i < nd; i++) {
        int64_t key = diffs[i];
        int j = i - 1;
        while (j >= 0 && diffs[j] > key) {
            diffs[j + 1] = diffs[j];
            j--;
        }
        diffs[j + 1] = key;
    }
    *delta_out = nd > 0 ? diffs[nd / 2] : 1;
    if (*delta_out <= 0) *delta_out = 1;
}

static int write_packet(AVFormatContext *out, AVStream *target, AVPacket *pkt) {
    pkt->stream_index = target->index;
    pkt->pos = -1;
    return av_interleaved_write_frame(out, pkt);
}

static int emit_video(AVFormatContext *out, AVStream *target, AVPacket *pkt,
                      struct VideoPipeline *pipe, AVRational in_tb) {
    int64_t dts = pkt->dts + pipe->shift;
    int64_t pts = (pkt->pts == AV_NOPTS_VALUE ? dts : pkt->pts + pipe->shift);
    if (pts < dts) pts = dts;
    pkt->pts = av_rescale_q(pts, in_tb, target->time_base);
    pkt->dts = av_rescale_q(dts, in_tb, target->time_base);
    if (pipe->last_dts != AV_NOPTS_VALUE && pkt->dts <= pipe->last_dts) {
        pkt->dts = pipe->last_dts + 1;
        if (pkt->pts < pkt->dts) pkt->pts = pkt->dts;
    }
    pipe->last_dts = pkt->dts;
    pkt->duration = 0; // the muxer derives per-sample durations from DTS deltas
    return write_packet(out, target, pkt);
}

static int emit_audio(AVFormatContext *out, AVStream *target, AVPacket *pkt,
                      struct AudioClock *clock, AVRational in_tb, int64_t fallback_duration) {
    int64_t pts = pkt->pts + clock->shift;
    if (pts < 0) pts = 0;
    if (pkt->duration <= 0) {
        pkt->duration = clock->last_duration > 0 ? clock->last_duration : fallback_duration;
    }
    if (clock->last_dts != AV_NOPTS_VALUE && pts <= clock->last_dts) {
        pts = clock->last_dts + pkt->duration;
    }
    clock->last_dts = pts;
    clock->last_duration = pkt->duration;
    pkt->pts = av_rescale_q(pts, in_tb, target->time_base);
    pkt->dts = pkt->pts;
    pkt->duration = av_rescale_q(pkt->duration, in_tb, target->time_base);
    return write_packet(out, target, pkt);
}

int rill_remux(const char *src, const char *dst, char *err, size_t err_len) {
    if (err && err_len > 0) err[0] = '\0';
    av_log_set_level(AV_LOG_ERROR);

    AVFormatContext *in = NULL;
    AVFormatContext *out = NULL;
    AVPacket *pkt = av_packet_alloc();
    struct HeldPacket *held = NULL;
    int held_count = 0, held_capacity = 0;
    struct VideoPipeline pipe = {0};
    int pipeline_ready = 0;
    int ret = RILL_REMUX_FAILED;
    int video = -1, audio = -1;
    struct AudioClock aclock = {0};

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
    for (unsigned i = 0; i < in->nb_streams && video < 0; i++) {
        const AVStream *s = in->streams[i];
        if (s->codecpar->codec_type != AVMEDIA_TYPE_VIDEO) continue;
        if (s->disposition & AV_DISPOSITION_ATTACHED_PIC) continue;
        if (s->codecpar->codec_id == AV_CODEC_ID_H264 ||
            s->codecpar->codec_id == AV_CODEC_ID_HEVC) {
            video = (int)i;
        }
    }
    for (unsigned i = 0; i < in->nb_streams && video < 0; i++) {
        const AVStream *s = in->streams[i];
        if (s->codecpar->codec_type == AVMEDIA_TYPE_VIDEO &&
            !(s->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
            video = (int)i;
        }
    }
    if (video < 0) {
        set_err(err, err_len, "no video stream");
        ret = RILL_REMUX_NO_VIDEO;
        goto done;
    }
    if (in->streams[video]->codecpar->codec_id != AV_CODEC_ID_H264 &&
        in->streams[video]->codecpar->codec_id != AV_CODEC_ID_HEVC) {
        set_err(err, err_len, "video codec %s cannot be copied into MP4",
                avcodec_get_name(in->streams[video]->codecpar->codec_id));
        ret = RILL_REMUX_UNSUPPORTED_CODEC;
        goto done;
    }

    // Bring the first AAC track along when there is one; other audio codecs
    // would make AVFoundation reject the result, and wallpapers stay muted.
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
    if (out->priv_data && av_opt_set(out->priv_data, "movflags", "+faststart", 0) < 0) {
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
    avret = avcodec_parameters_copy(video_out->codecpar, in->streams[video]->codecpar);
    if (avret < 0) {
        set_err(err, err_len, "copy parameters: av error %d", avret);
        goto done;
    }
    // AVFoundation only accepts HEVC tagged hvc1; H.264 keeps the muxer default.
    if (in->streams[video]->codecpar->codec_id == AV_CODEC_ID_HEVC)
        video_out->codecpar->codec_tag = MKTAG('h', 'v', 'c', '1');
    video_out->time_base = in->streams[video]->time_base;

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
        audio_out->time_base = in->streams[audio]->time_base;
    }

    if ((avret = avformat_write_header(out, NULL)) < 0) {
        set_err(err, err_len, "write header: av error %d", avret);
        goto done;
    }

    held_capacity = 256;
    held = av_malloc_array(held_capacity, sizeof *held);
    if (!held) {
        set_err(err, err_len, "out of memory");
        goto done;
    }

    // One pass: every wanted packet lands in `held` in arrival order. Once
    // enough video has arrived, the pipeline starts assigning DTS values to
    // video slots as they become unambiguous, and the resolved prefix of
    // `held` is written out.
    int video_seen = 0, emit_index = 0;
    while (1) {
        if ((avret = av_read_frame(in, pkt)) < 0) break;
        int is_video = pkt->stream_index == video;
        if (!is_video && !(audio >= 0 && pkt->stream_index == audio)) {
            av_packet_unref(pkt);
            continue;
        }
        if (held_count == held_capacity) {
            int new_capacity = held_capacity * 2;
            struct HeldPacket *grown = av_realloc_array(held, new_capacity, sizeof *held);
            if (!grown) {
                av_packet_unref(pkt);
                set_err(err, err_len, "out of memory");
                goto done;
            }
            held = grown;
            held_capacity = new_capacity;
        }
        held[held_count].pkt = av_packet_alloc();
        if (!held[held_count].pkt) {
            av_packet_unref(pkt);
            set_err(err, err_len, "out of memory");
            goto done;
        }
        av_packet_move_ref(held[held_count].pkt, pkt);
        held[held_count].is_video = is_video;
        held[held_count].video_slot = is_video ? video_seen : -1;
        held[held_count].dts = AV_NOPTS_VALUE;
        held_count++;
        if (!is_video) continue;
        video_seen++;

        if (!pipeline_ready && video_seen >= WINDOW) {
            int64_t window_pts[WINDOW];
            int n_window = 0;
            for (int i = 0; i < held_count && n_window < WINDOW; i++) {
                if (held[i].is_video && held[i].pkt->pts != AV_NOPTS_VALUE) {
                    window_pts[n_window++] = held[i].pkt->pts;
                }
            }
            int delay = 0;
            int64_t delta = 1;
            measure_window(window_pts, n_window, &delay, &delta);
            pipeline_init(&pipe, delay, delta);
            if (!pipe.sorted) {
                set_err(err, err_len, "out of memory");
                goto done;
            }
            pipeline_ready = 1;
            for (int i = 0; i < held_count; i++) {
                if (held[i].is_video) pipeline_feed_pts(&pipe, held[i].pkt->pts);
            }
        } else if (pipeline_ready) {
            pipeline_feed_pts(&pipe, pkt->pts);
        }
        if (!pipeline_ready) continue;

        while (pipeline_slot_ready(&pipe)) {
            pipeline_assign(&pipe, pipeline_pop_min(&pipe), held, held_count);
        }
        if (audio >= 0 && aclock.shift == 0 && pipe.released > 0) {
            aclock.shift = av_rescale_q(pipe.shift,
                                        in->streams[video]->time_base,
                                        in->streams[audio]->time_base);
        }

        // Emit the prefix where every packet either needs no DTS (audio) or
        // already has one.
        while (emit_index < held_count &&
               (!held[emit_index].is_video || held[emit_index].dts != AV_NOPTS_VALUE)) {
            int avw;
            if (held[emit_index].is_video) {
                held[emit_index].pkt->dts = held[emit_index].dts;
                avw = emit_video(out, video_out, held[emit_index].pkt, &pipe,
                                 in->streams[video]->time_base);
            } else {
                avw = emit_audio(out, audio_out, held[emit_index].pkt, &aclock,
                                 in->streams[audio]->time_base, 1024);
            }
            av_packet_free(&held[emit_index].pkt);
            emit_index++;
            if (avw < 0) {
                set_err(err, err_len, "write packet: av error %d", avw);
                goto done;
            }
        }
        if (emit_index > 4096) {
            // Keep the held array flat over hours-long files.
            memmove(held, held + emit_index, (held_count - emit_index) * sizeof *held);
            held_count -= emit_index;
            emit_index = 0;
        }
    }

    if (!pipeline_ready) {
        // EOF before the window filled: measure from whatever arrived.
        int64_t window_pts[WINDOW];
        int n_window = 0;
        for (int i = 0; i < held_count && n_window < WINDOW; i++) {
            if (held[i].is_video && held[i].pkt->pts != AV_NOPTS_VALUE) {
                window_pts[n_window++] = held[i].pkt->pts;
            }
        }
        int delay = 0;
        int64_t delta = 1;
        measure_window(window_pts, n_window, &delay, &delta);
        pipeline_init(&pipe, delay, delta);
        if (!pipe.sorted) {
            set_err(err, err_len, "out of memory");
            goto done;
        }
        pipeline_ready = 1;
        for (int i = 0; i < held_count; i++) {
            if (held[i].is_video) pipeline_feed_pts(&pipe, held[i].pkt->pts);
        }
        while (pipeline_slot_ready(&pipe)) {
            pipeline_assign(&pipe, pipeline_pop_min(&pipe), held, held_count);
        }
        if (audio >= 0 && pipe.released > 0) {
            aclock.shift = av_rescale_q(pipe.shift,
                                        in->streams[video]->time_base,
                                        in->streams[audio]->time_base);
        }
    }

    // End of input: remaining pipeline values are the DTS values of the
    // last video slots (the encoder-flush tail).
    while (pipe.size > 0 && pipeline_slot_ready(&pipe)) {
        pipeline_assign(&pipe, pipeline_pop_min(&pipe), held, held_count);
    }
    int64_t tail_dts = AV_NOPTS_VALUE;
    for (int i = held_count - 1; i >= 0; i--) {
        if (held[i].is_video && held[i].dts != AV_NOPTS_VALUE) {
            tail_dts = held[i].dts;
            break;
        }
    }
    while (emit_index < held_count) {
        int avw;
        if (held[emit_index].is_video) {
            if (held[emit_index].dts == AV_NOPTS_VALUE) {
                if (tail_dts == AV_NOPTS_VALUE) tail_dts = 0;
                tail_dts += pipe.delta;
                held[emit_index].dts = tail_dts;
            }
            held[emit_index].pkt->dts = held[emit_index].dts;
            avw = emit_video(out, video_out, held[emit_index].pkt, &pipe,
                             in->streams[video]->time_base);
        } else {
            avw = emit_audio(out, audio_out, held[emit_index].pkt, &aclock,
                             in->streams[audio]->time_base, 1024);
        }
        av_packet_free(&held[emit_index].pkt);
        emit_index++;
        if (avw < 0) {
            set_err(err, err_len, "write packet: av error %d", avw);
            goto done;
        }
    }
    held_count = emit_index;

    if ((avret = av_write_trailer(out)) < 0) {
        set_err(err, err_len, "write trailer: av error %d", avret);
        goto done;
    }
    ret = RILL_REMUX_OK;

done:
    if (pipeline_ready) pipeline_free(&pipe);
    if (held) {
        for (int i = 0; i < held_count; i++) {
            if (held[i].pkt) av_packet_free(&held[i].pkt);
        }
        av_freep(&held);
    }
    av_packet_free(&pkt);
    if (out) {
        if (!(out->flags & AVFMT_NOFILE) && out->pb) avio_closep(&out->pb);
        avformat_free_context(out);
    }
    avformat_close_input(&in);
    return ret;
}
