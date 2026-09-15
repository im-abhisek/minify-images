import Foundation

/// Same quality policy as `src/cli.mjs` `webpOptions`.
/// Keep the two in lockstep: visually lossless photos, lossless PNG+alpha, near-lossless opaque PNG.
enum SourceKind: String, Equatable {
    case jpeg
    case png
}

struct ConversionSettings: Equatable, Sendable {
    var quality: Int = 90
    var maxDimension: Int? = nil
    var pngStrategy: PNGStrategy = .preserve
    var includeSubfolders: Bool = false
    var outputFolder: URL? = nil

    var lossless: Bool { pngStrategy == .lossless }
    var photo: Bool { pngStrategy == .photo }
}

enum PNGStrategy: String, CaseIterable, Identifiable, Sendable {
    case preserve
    case photo
    case lossless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preserve: return "Auto"
        case .photo: return "Photo"
        case .lossless: return "Lossless"
        }
    }

    var caption: String {
        switch self {
        case .preserve:
            return "Transparent PNG stays lossless. Opaque PNG uses near-lossless. JPEG uses quality."
        case .photo:
            return "Treat PNG like a photograph (lossy quality, alpha kept)."
        case .lossless:
            return "Exact pixels for every file. Larger, best for logos and UI."
        }
    }
}

enum EncodeRecipe: Equatable, Sendable {
    case lossless(exact: Bool)
    case nearLossless(quality: Int)
    case photo(quality: Int)

    var label: String {
        switch self {
        case .lossless(let exact):
            return exact ? "png+alpha, lossless" : "lossless"
        case .nearLossless(let quality):
            return "png, near-lossless q\(quality)"
        case .photo(let quality):
            return "photo, q\(quality)"
        }
    }

    func label(hasAlpha: Bool) -> String {
        switch self {
        case .lossless:
            return hasAlpha ? "png+alpha, lossless" : "lossless"
        case .nearLossless(let quality):
            return "png, near-lossless q\(quality)"
        case .photo(let quality):
            return hasAlpha ? "photo+alpha, q\(quality)" : "photo, q\(quality)"
        }
    }
}

enum QualityPolicy {
    static func recipe(
        kind: SourceKind,
        hasAlpha: Bool,
        quality: Int,
        lossless: Bool,
        photo: Bool
    ) -> EncodeRecipe {
        let forceLossless = lossless
        let pngPreserve = kind == .png && !photo && !forceLossless

        if forceLossless || (pngPreserve && hasAlpha) {
            return .lossless(exact: hasAlpha)
        }
        if pngPreserve {
            return .nearLossless(quality: quality)
        }
        return .photo(quality: quality)
    }

    static func recipe(kind: SourceKind, hasAlpha: Bool, settings: ConversionSettings) -> EncodeRecipe {
        recipe(
            kind: kind,
            hasAlpha: hasAlpha,
            quality: settings.quality,
            lossless: settings.lossless,
            photo: settings.photo
        )
    }
}
