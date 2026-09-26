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
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text(outputCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(outputHelp)
                OutputLink(title: folderChosen ? "Change" : "Choose Folder") {
                    let revertIfCancelled = self.model.outputMode != .folder
                    self.model.chooseOutputFolder(revertIfCancelled: revertIfCancelled)
                }
                if folderChosen {
                    OutputLink(title: "Use originals", size: 12) {
                        self.model.outputMode = .besideOriginals
                        self.model.rememberOutputMode()
                    }
                }
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
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(model.quality)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
            }
            // Omit step so macOS does not draw tick marks. The binding still snaps to whole numbers.
            Slider(value: qualityBinding, in: 0...100)
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

/// Blue underlined text button. No fill and no bezel.
private struct OutputLink: View {
    let title: String
    var size: CGFloat = 12.5
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size))
                .foregroundStyle(Color.blue.opacity(isEnabled ? 1 : 0.4))
                .underline()
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}
