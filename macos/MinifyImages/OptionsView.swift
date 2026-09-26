import SwiftUI

struct OptionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            outputColumn
                .frame(maxWidth: .infinity, alignment: .leading)
            qualityColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    private var outputColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Output")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(outputCaption)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(outputHelp)
                        .layoutPriority(-1)
                    if folderChosen {
                        Button {
                            self.model.clearChosenOutputFolder()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Use originals")
                        .accessibilityLabel("Use originals")
                    }
                }
                OutputLink(title: folderChosen ? "Change" : "Choose Folder") {
                    let revertIfCancelled = self.model.outputMode != .folder
                    self.model.chooseOutputFolder(revertIfCancelled: revertIfCancelled)
                }
                Spacer(minLength: 0)
            }
            .disabled(self.model.isRunning)
        }
    }

    private var folderChosen: Bool {
        model.outputMode == .folder && model.outputFolder != nil
    }

    private var outputCaption: String {
        if folderChosen, let name = model.outputFolder?.lastPathComponent, !name.isEmpty {
            return name
        }
        return "Next to originals"
    }

    private var outputHelp: String {
        if folderChosen, let path = model.outputFolder?.path {
            return path
        }
        return "WebP files are written beside each original"
    }

    private var qualityColumn: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Quality")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(model.quality)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
            }
            // A custom track so macOS does not draw tick marks. The binding still snaps to whole numbers.
            QualityGradientSlider(value: qualityBinding)
                .disabled(model.isRunning)
        }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(self.model.quality) },
            set: { self.model.quality = QualityPolicy.clampedQuality(Int($0.rounded())) }
        )
    }
}

/// Full-track gradient: red at 0, yellow through the middle, green by about 80.
/// 75 lands in the middle of the yellow-to-green blend.
private struct QualityGradientSlider: View {
    @Binding var value: Double
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool

    private let thumb: CGFloat = 16

    private static let gradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .red, location: 0),
            Gradient.Stop(color: .yellow, location: 0.50),
            Gradient.Stop(color: .yellow, location: 0.70),
            Gradient.Stop(color: .green, location: 0.80),
            Gradient.Stop(color: .green, location: 1)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width - self.thumb, 1)
            let fraction = min(1, max(0, self.value / 100))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Self.gradient)
                    .frame(height: 6)
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().strokeBorder(
                            self.focused ? Color.white.opacity(0.9) : Color.black.opacity(0.28),
                            lineWidth: self.focused ? 1.5 : 0.5
                        )
                    )
                    .frame(width: self.thumb, height: self.thumb)
                    .shadow(color: Color.black.opacity(0.35), radius: 1.5, y: 0.5)
                    .offset(x: fraction * span)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard self.isEnabled else { return }
                        self.setValue(x: gesture.location.x, span: span)
                    }
            )
        }
        .frame(height: 22)
        .opacity(isEnabled ? 1 : 0.4)
        .focusable(isEnabled)
        .focused(self.$focused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            self.nudge(-1)
        }
        .onKeyPress(.downArrow) {
            self.nudge(-1)
        }
        .onKeyPress(.rightArrow) {
            self.nudge(1)
        }
        .onKeyPress(.upArrow) {
            self.nudge(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quality")
        .accessibilityValue(Text("\(Int(value.rounded()))"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                self.nudge(1)
            case .decrement:
                self.nudge(-1)
            default:
                break
            }
        }
    }

    private func setValue(x: CGFloat, span: CGFloat) {
        let clamped = min(max(x - self.thumb / 2, 0), span)
        self.value = Double(clamped / span) * 100
    }

    @discardableResult
    private func nudge(_ delta: Double) -> KeyPress.Result {
        guard self.isEnabled else { return .ignored }
        self.value = min(100, max(0, self.value + delta))
        return .handled
    }
}

/// Blue underlined text button. No fill and no bezel.
private struct OutputLink: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.blue.opacity(isEnabled ? 1 : 0.4))
                .underline()
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}
