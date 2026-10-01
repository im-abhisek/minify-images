import Foundation
import WebPBridge

enum WebPEncoder {
    static func requestCancel() {
        minify_webp_request_cancel()
    }

    static var generation: Int32 {
        minify_webp_current_generation()
    }

    static func encode(image: DecodedImage, recipe: EncodeRecipe) throws -> Data {
        let generation = Self.generation
        if Task.isCancelled {
            throw CancellationError()
        }
        var options = MinifyWebPEncodeOptions()
        switch recipe {
        case .photo(let quality):
            options.mode = MINIFY_WEBP_MODE_PHOTO
            options.quality = Self.webpQuality(quality)
            options.exact = 0
        case .lossless(let exact):
            options.mode = MINIFY_WEBP_MODE_LOSSLESS
            options.quality = 100
            options.exact = exact ? 1 : 0
        case .nearLossless(let quality):
            options.mode = MINIFY_WEBP_MODE_NEAR_LOSSLESS
            options.quality = Self.webpQuality(quality)
            options.exact = 0
        }

        var outBuf: UnsafeMutablePointer<UInt8>?
        var outLen: Int = 0
        let status: Int32 = image.rgba.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return -1 }
            return minify_webp_encode_rgba(
                base,
                Int32(image.width),
                Int32(image.height),
                Int32(image.width * 4),
                options,
                &outBuf,
                &outLen
            )
        }

        if status == -7 || Self.generation != generation {
            if let outBuf {
                minify_webp_free(outBuf)
            }
            throw CancellationError()
        }
        guard status == 0, let outBuf, outLen > 0 else {
            throw EncodeError.failed(code: Int(status))
        }
        defer { minify_webp_free(outBuf) }
        return Data(bytes: outBuf, count: outLen)
    }

    /// 0...100 inclusive. libwebp rejects values outside that range and accepts 0.
    private static func webpQuality(_ quality: Int) -> Float {
        Float(QualityPolicy.clampedQuality(quality))
    }

    enum EncodeError: LocalizedError {
        case failed(code: Int)

        var errorDescription: String? {
            switch self {
            case .failed(let code):
                return "WebP encoding failed (\(code))"
            }
        }
    }
}
