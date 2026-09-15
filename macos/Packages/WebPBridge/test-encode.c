#include "MinifyWebPBridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <webp/decode.h>

static int fail(const char *message, int code) {
    fprintf(stderr, "fail: %s (%d)\n", message, code);
    return 1;
}

int main(void) {
    const int width = 32;
    const int height = 32;
    uint8_t *rgba = calloc((size_t)width * (size_t)height * 4, 1);
    if (!rgba) return fail("alloc", -1);

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            const int i = (y * width + x) * 4;
            const int inside = (x - 16) * (x - 16) + (y - 16) * (y - 16) < 12 * 12;
            rgba[i] = 220;
            rgba[i + 1] = 40;
            rgba[i + 2] = 80;
            rgba[i + 3] = inside ? 255 : 0;
        }
    }

    MinifyWebPEncodeOptions options = {
        .mode = MINIFY_WEBP_MODE_LOSSLESS,
        .quality = 90,
        .exact = 1,
    };

    uint8_t *out = NULL;
    size_t len = 0;
    const int status = minify_webp_encode_rgba(
        rgba, width, height, width * 4, options, &out, &len
    );

    if (status != 0 || out == NULL || len < 12) {
        free(rgba);
        minify_webp_free(out);
        return fail("encode", status);
    }

    if (memcmp(out, "RIFF", 4) != 0 || memcmp(out + 8, "WEBP", 4) != 0) {
        free(rgba);
        minify_webp_free(out);
        return fail("not a webp", 0);
    }

    int decodedW = 0;
    int decodedH = 0;
    uint8_t *decoded = WebPDecodeRGBA(out, len, &decodedW, &decodedH);
    if (decoded == NULL || decodedW != width || decodedH != height) {
        free(rgba);
        minify_webp_free(out);
        return fail("decode", 0);
    }
    int alphaKept = 0;
    int opaqueKept = 0;
    for (int i = 0; i < width * height; i++) {
        const int srcA = rgba[i * 4 + 3];
        const int dstA = decoded[i * 4 + 3];
        if (srcA == 0 && dstA == 0) alphaKept += 1;
        if (srcA == 255 && dstA == 255) opaqueKept += 1;
    }
    WebPFree(decoded);
    free(rgba);
    if (alphaKept == 0 || opaqueKept == 0) {
        minify_webp_free(out);
        return fail("alpha not preserved", 0);
    }

    printf("ok  lossless rgba %dx%d → %zu bytes (alpha kept)\n", width, height, len);
    minify_webp_free(out);

    uint8_t photo[16] = {
        40, 80, 120, 255,
        41, 81, 121, 255,
        42, 82, 122, 255,
        200, 40, 40, 255,
    };
    options.mode = MINIFY_WEBP_MODE_PHOTO;
    options.quality = 90;
    options.exact = 0;
    out = NULL;
    len = 0;
    const int photoStatus = minify_webp_encode_rgba(photo, 2, 2, 8, options, &out, &len);
    if (photoStatus != 0 || out == NULL || len < 12) {
        minify_webp_free(out);
        return fail("photo encode", photoStatus);
    }
    printf("ok  photo rgb %zu bytes\n", len);
    minify_webp_free(out);
    return 0;
}
