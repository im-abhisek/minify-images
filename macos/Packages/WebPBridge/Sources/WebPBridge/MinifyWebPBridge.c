#include "MinifyWebPBridge.h"

#include <webp/encode.h>

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

    if (!WebPPictureImportRGBA(&picture, rgba, stride)) {
        WebPPictureFree(&picture);
        return -5;
    }

    WebPMemoryWriter writer;
    WebPMemoryWriterInit(&writer);
    picture.writer = WebPMemoryWrite;
    picture.custom_ptr = &writer;

    const int ok = WebPEncode(&config, &picture);
    WebPPictureFree(&picture);

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
