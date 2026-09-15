#ifndef MINIFY_WEBP_BRIDGE_H
#define MINIFY_WEBP_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    MINIFY_WEBP_MODE_PHOTO = 0,
    MINIFY_WEBP_MODE_LOSSLESS = 1,
    MINIFY_WEBP_MODE_NEAR_LOSSLESS = 2
} MinifyWebPMode;

typedef struct {
    MinifyWebPMode mode;
    float quality;
    int exact;
} MinifyWebPEncodeOptions;

/// Encode 8-bit RGBA (unpremultiplied) into a WebP buffer.
/// On success returns 0 and transfers ownership of *out_buf (free with minify_webp_free).
int minify_webp_encode_rgba(
    const uint8_t *rgba,
    int width,
    int height,
    int stride,
    MinifyWebPEncodeOptions options,
    uint8_t **out_buf,
    size_t *out_len
);

void minify_webp_free(uint8_t *buf);

#ifdef __cplusplus
}
#endif

#endif
