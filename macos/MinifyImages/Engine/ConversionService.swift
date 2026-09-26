import Foundation
import ImageIO

struct ConversionResult: Equatable, Sendable {
    let destination: URL
    let sourceBytes: Int
    let destBytes: Int
    let width: Int
    let height: Int
    let hasAlpha: Bool
    let label: String
}

enum ConversionService {
    static func convert(source: URL, root: URL, settings: ConversionSettings) throws -> ConversionResult {
        let dest = OutputPaths.webpURL(for: source, root: root, outDir: settings.outputFolder)
        let sourceBytes = try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int ?? 0

        let decoded = try ImageDecoder.decode(url: source, maxDimension: settings.maxDimension)
        let recipe = QualityPolicy.recipe(kind: decoded.kind, hasAlpha: decoded.hasAlpha, settings: settings)
        let data = try WebPEncoder.encode(image: decoded, recipe: recipe)

        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: dest, options: .atomic)

        let destBytes = data.count
        return ConversionResult(
            destination: dest,
            sourceBytes: sourceBytes,
            destBytes: destBytes,
            width: decoded.width,
            height: decoded.height,
            hasAlpha: decoded.hasAlpha,
            label: recipe.label(hasAlpha: decoded.hasAlpha)
        )
    }

    static func webpHasAlpha(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return false
        }
        return ImageDecoder.hasAlphaChannel(image)
    }
}

enum ByteFormat {
    static func string(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
    }

    static func savings(from: Int, to: Int) -> String {
        guard from > 0 else { return "n/a" }
        let pct = Int(((1 - Double(to) / Double(from)) * 100).rounded())
        let sign = to <= from ? "−" : "+"
        return "\(sign)\(abs(pct))%"
    }

    /// One decimal, POSIX separator, so the status bar reads "18.4 MB" / "7.0 MB".
    static func statusSize(_ bytes: Int) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", locale: posix, Double(bytes) / (1024 * 1024))
        }
        if bytes >= 1024 {
            return String(format: "%.1f KB", locale: posix, Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }

    static func savedPercent(from source: Int, to dest: Int) -> Int {
        guard source > 0 else { return 0 }
        return Int((Double(source - dest) / Double(source) * 100).rounded())
    }
}
