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
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var outputColumn: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            Text("Output")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            OutputChoiceControl()
                .disabled(self.model.isRunning)

            if let path = model.outputFolderDisplay {
                Text(path)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(model.outputFolder?.path ?? path)
            }
        }
    }

    private var qualityColumn: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Quality")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(model.quality)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
            }
            Slider(value: qualityBinding, in: 70...100, step: 1)
                .disabled(model.isRunning)
        }
    }

    private var qualityBinding: Binding<Double> {
        Binding(
            get: { Double(self.model.quality) },
            set: { self.model.quality = Int($0.rounded()) }
        )
    }
}

/// Two segments. "Choose" always opens the folder panel, including when it is already selected.
private struct OutputChoiceControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 2) {
            segment(.besideOriginals) {
                self.model.outputMode = .besideOriginals
                self.model.rememberOutputMode()
            }
            segment(.folder) {
                let revertIfCancelled = self.model.outputMode != .folder
                self.model.chooseOutputFolder(revertIfCancelled: revertIfCancelled)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Output")
    }

    private func segment(_ mode: OutputMode, action: @escaping () -> Void) -> some View {
        let selected = model.outputMode == mode
        return Button(action: action) {
            Text(mode.title)
                .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.blue : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}
