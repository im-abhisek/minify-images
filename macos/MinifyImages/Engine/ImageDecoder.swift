import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct DecodedImage: Sendable {
    let rgba: [UInt8]
    let width: Int
    let height: Int
    let kind: SourceKind
    let hasAlpha: Bool
}

enum ImageDecoder {
    static func decode(url: URL, maxDimension: Int?) throws -> DecodedImage {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            throw DecodeError.unreadable(url)
        }
        guard let typeIdentifier = CGImageSourceGetType(source) as String? else {
            throw DecodeError.unreadable(url)
        }

        let kind = try sourceKind(for: typeIdentifier, fallbackExtension: url.pathExtension)

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let pixelHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let longest = max(pixelWidth, pixelHeight, 1)
        let cap: Int
        if let maxDimension {
            cap = min(maxDimension, longest)
        } else {
            cap = longest
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: cap,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw DecodeError.unreadable(url)
        }

        let hasAlpha = hasAlphaChannel(cgImage)
        let (bytes, width, height) = try rgbaPixels(from: cgImage)
        return DecodedImage(rgba: bytes, width: width, height: height, kind: kind, hasAlpha: hasAlpha)
    }

    static func sourceKind(for typeIdentifier: String, fallbackExtension: String) throws -> SourceKind {
        if let type = UTType(typeIdentifier) {
            if type.conforms(to: .jpeg) { return .jpeg }
            if type.conforms(to: .png) { return .png }
        }
        switch fallbackExtension.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        default:
            throw DecodeError.unsupportedType(typeIdentifier)
        }
    }

    static func hasAlphaChannel(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipLast, .noneSkipFirst:
            return false
        default:
            return true
        }
    }

    private static func rgbaPixels(from image: CGImage) throws -> ([UInt8], Int, Int) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw DecodeError.emptyImage
        }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        try bytes.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                throw DecodeError.bitmapFailed
            }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        unpremultiply(&bytes)
        return (bytes, width, height)
    }

    /// libwebp ImportRGBA expects straight (unpremultiplied) alpha.
    private static func unpremultiply(_ bytes: inout [UInt8]) {
        let count = bytes.count / 4
        for i in 0..<count {
            let o = i * 4
            let a = bytes[o + 3]
            if a == 0 {
                bytes[o] = 0
                bytes[o + 1] = 0
                bytes[o + 2] = 0
                continue
            }
            if a == 255 { continue }
            bytes[o] = UInt8(min(255, Int(bytes[o]) * 255 / Int(a)))
            bytes[o + 1] = UInt8(min(255, Int(bytes[o + 1]) * 255 / Int(a)))
            bytes[o + 2] = UInt8(min(255, Int(bytes[o + 2]) * 255 / Int(a)))
        }
    }

    enum DecodeError: LocalizedError {
        case unreadable(URL)
        case unsupportedType(String)
        case emptyImage
        case bitmapFailed

        var errorDescription: String? {
            switch self {
            case .unreadable(let url):
                return "Couldn’t read \(url.lastPathComponent)"
            case .unsupportedType:
                return "Not a JPEG or PNG"
            case .emptyImage:
                return "Image has no pixels"
            case .bitmapFailed:
                return "Couldn’t decode pixels"
            }
        }
    }
}
