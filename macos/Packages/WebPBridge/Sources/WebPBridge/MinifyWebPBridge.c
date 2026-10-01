#include "MinifyWebPBridge.h"

#include <stdatomic.h>
#include <webp/encode.h>

static atomic_int g_minify_webp_generation = 0;

static int minify_webp_progress(int percent, const WebPPicture *picture) {
    (void)percent;
    const int *started = picture->user_data;
    if (started != NULL && *started != atomic_load_explicit(&g_minify_webp_generation, memory_order_acquire)) {
        return 0;
    }
    return 1;
}

void minify_webp_request_cancel(void) {
    atomic_fetch_add_explicit(&g_minify_webp_generation, 1, memory_order_acq_rel);
}

int minify_webp_current_generation(void) {
    return atomic_load_explicit(&g_minify_webp_generation, memory_order_acquire);
}

int minify_webp_encode_rgba(
    const uint8_t *rgba,
    int width,
    int height,
    int stride,
    MinifyWebPEncodeOptions options,
    uint8_t **out_buf,
    size_t *out_len
) {
    if (rgba == NULL || out_buf == NULL || out_len == NULL || width <= 0 || height <= 0 || stride < width * 4) {
        return -1;
    }

    WebPConfig config;
    if (options.mode == MINIFY_WEBP_MODE_PHOTO) {
        if (!WebPConfigPreset(&config, WEBP_PRESET_PHOTO, options.quality)) {
            return -2;
        }
        config.quality = options.quality;
        config.method = 6;
        config.alpha_quality = 100;
        config.use_sharp_yuv = 1;
        // libwebp 1.5 accepts only 0 or 1. 1 turns on its worker thread.
        config.thread_level = 1;
    } else if (options.mode == MINIFY_WEBP_MODE_LOSSLESS) {
        if (!WebPConfigPreset(&config, WEBP_PRESET_DEFAULT, 100)) {
            return -2;
        }
        config.lossless = 1;
        config.method = 6;
        config.alpha_quality = 100;
        config.exact = options.exact ? 1 : 0;
        config.thread_level = 1;
    } else {
        if (!WebPConfigPreset(&config, WEBP_PRESET_DEFAULT, options.quality)) {
            return -2;
        }
        config.lossless = 1;
        config.near_lossless = (int)options.quality;
        config.quality = options.quality;
        config.method = 6;
        config.alpha_quality = 100;
        config.thread_level = 1;
    }

    if (!WebPValidateConfig(&config)) {
        return -3;
    }

    WebPPicture picture;
    if (!WebPPictureInit(&picture)) {
        return -4;
    }

    picture.use_argb = config.lossless ? 1 : 0;
    picture.width = width;
    picture.height = height;
    int started = minify_webp_current_generation();

    if (!WebPPictureImportRGBA(&picture, rgba, stride)) {
        WebPPictureFree(&picture);
        return -5;
    }
    if (started != minify_webp_current_generation()) {
        WebPPictureFree(&picture);
        return -7;
    }

    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    picture.writer = WebPMemoryWrite;
    picture.custom_ptr = &writer;
    picture.progress_hook = minify_webp_progress;
    picture.user_data = &started;

    const int ok = WebPEncode(&config, &picture);
    const int aborted = picture.error_code == VP8_ENC_ERROR_USER_ABORT
        || started != minify_webp_current_generation();
    WebPPictureFree(&picture);

    if (aborted) {
        WebPMemoryWriterClear(&writer);
        return -7;
    }

    if (!ok || writer.mem == NULL || writer.size == 0) {
        WebPMemoryWriterClear(&writer);
        return -6;
    }

    *out_buf = writer.mem;
    *out_len = writer.size;
    return 0;
}

void minify_webp_free(uint8_t *buf) {
    WebPFree(buf);
}
