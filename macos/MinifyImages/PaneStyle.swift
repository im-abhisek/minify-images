import SwiftUI

/// TEMPORARY live comparison. Delete this file and the "Pane Style" menu
/// once a border and a fill are chosen.

enum PaneBorderStyle: String, CaseIterable, Identifiable {
    case gradient
    case solidBlack
    case none

    static let storageKey = "temporary.paneStyle.border"

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .gradient: "Gradient (white to black)"
        case .solidBlack: "Solid black"
        case .none: "None"
        }
    }

    /// `nil` draws no stroke. Drag-over still paints the blue edge separately.
    var strokeStyle: AnyShapeStyle? {
        switch self {
        case .gradient:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.black.opacity(0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .solidBlack:
            AnyShapeStyle(Color.black.opacity(0.68))
        case .none:
            nil
        }
    }
}

enum PaneFillStyle: String, CaseIterable, Identifiable {
    case gradient
    case flatGrey
    case darkGrey

    static let storageKey = "temporary.paneStyle.fill"
    /// Starting colour of the fill gradient. Dark grey uses this flat.
    static let gradientTop = Color.black.opacity(0.16)
    static let gradientBottom = Color.white.opacity(0.05)

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .gradient: "Gradient"
        case .flatGrey: "Flat grey"
        case .darkGrey: "Dark grey"
        }
    }

    var fillStyle: AnyShapeStyle {
        switch self {
        case .gradient:
            AnyShapeStyle(
                LinearGradient(
                    colors: [Self.gradientTop, Self.gradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .flatGrey:
            AnyShapeStyle(Self.gradientBottom)
        case .darkGrey:
            AnyShapeStyle(Self.gradientTop)
        }
    }
}

/// Checkmarked Border and Fill choices. Stored in UserDefaults.
struct PaneStyleMenu: View {
    @AppStorage(PaneBorderStyle.storageKey) private var border: PaneBorderStyle = .solidBlack
    @AppStorage(PaneFillStyle.storageKey) private var fill: PaneFillStyle = .gradient

    var body: some View {
        Picker("Border", selection: self.$border) {
            ForEach(PaneBorderStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.inline)

        Divider()

        Picker("Fill", selection: self.$fill) {
            ForEach(PaneFillStyle.allCases) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.inline)
    }
}
