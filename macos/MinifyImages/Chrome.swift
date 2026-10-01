import SwiftUI

/// Grey fill, blue label. Used for every clickable control in the window.
struct MinifyButtonStyle: ButtonStyle {
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(isEnabled ? Color.blue : Color(nsColor: .tertiaryLabelColor))
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

/// Empty-pane Add Files control. Same footprint as the grey buttons, filled with the accent.
struct FilledBlueButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(self.isEnabled ? Color.white : Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.fill(isPressed: configuration.isPressed))
            )
            .onHover { hovering in
                self.isHovering = hovering
            }
    }

    private func fill(isPressed: Bool) -> Color {
        guard self.isEnabled else { return Color.white.opacity(0.07) }
        if isPressed { return Color.accentColor.opacity(0.72) }
        if self.isHovering { return Color.accentColor.opacity(0.88) }
        return Color.accentColor
    }
}

/// Neutral filled button. Same size as the blue one. White label, lighter on hover, darker on press.
struct FilledGreyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(self.isEnabled ? Color.white : Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.fill(isPressed: configuration.isPressed))
            )
            .onHover { hovering in
                self.isHovering = hovering
            }
    }

    private func fill(isPressed: Bool) -> Color {
        guard self.isEnabled else { return Color.white.opacity(0.06) }
        if isPressed { return Color.white.opacity(0.07) }
        if self.isHovering { return Color.white.opacity(0.18) }
        return Color.white.opacity(0.12)
    }
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
