import SwiftUI

/// Grey fill, blue label. Used for every clickable control in the window.
struct MinifyButtonStyle: ButtonStyle {
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Color.blue.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 3 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                    .fill((configuration.isPressed ? Self.fillPressed : Self.fill).opacity(isEnabled ? 1 : 0.45))
            )
    }

    /// Lighter than the dark window background.
    private static let fill = Color(white: 0.32)
    private static let fillPressed = Color(white: 0.42)
}

/// Yellow circular spinner for the batch status bar and in-row progress.
struct YellowSpinner: View {
    var side: CGFloat = 13

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let cycle = 0.75
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let fraction = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
            Circle()
                .trim(from: 0.14, to: 0.82)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: side, height: side)
                .rotationEffect(.degrees(fraction * 360))
        }
        .accessibilityLabel("In progress")
    }
}
