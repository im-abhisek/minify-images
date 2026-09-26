import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            header

            HStack(alignment: .stretch, spacing: 14) {
                DropZoneView()
                    .frame(width: 220)
                JobListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            OptionsView()
            actionBar
            StatusBar()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .onDrop(of: [.fileURL, .folder, .directory], isTargeted: $model.isTargeted) { providers in
            Task {
                let urls = await DroppedFileLoader.urls(from: providers)
                model.addDroppedURLs(urls)
            }
            return true
        }
        .frame(
            minWidth: 840,
            idealWidth: 920,
            maxWidth: 1600,
            minHeight: 620,
            idealHeight: 700,
            maxHeight: 1200
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Minify Images")
                .font(.system(size: 20, weight: .semibold))
            Text("JPEG & PNG → WebP")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Spacer()
            if !model.jobs.isEmpty {
                Button("Clear") {
                    model.clear()
                }
                .disabled(model.isRunning)
                .buttonStyle(MinifyButtonStyle())
            }
            if model.isRunning {
                Button("Cancel") {
                    model.cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(MinifyButtonStyle())
            }
            Button(model.isRunning ? "Converting…" : convertTitle) {
                model.convert()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(MinifyButtonStyle())
            .disabled(!model.canConvert)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    private var convertTitle: String {
        let n = model.jobs.count
        if n == 0 { return "Convert" }
        return n == 1 ? "Convert 1 image" : "Convert \(n) images"
    }
}

private struct StatusBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            HStack(spacing: 8) {
                statusMark
                    .frame(width: 16, height: 16)
                Text(statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(emphasize ? Color.primary : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let summary = model.lastSummary, summary.converted > 0, !model.isRunning {
                    Button("Show in Finder") {
                        model.revealOutputs()
                    }
                    .buttonStyle(MinifyButtonStyle(compact: true))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.05))
    }

    private var emphasize: Bool {
        model.isRunning || model.lastSummary != nil
    }

    private var statusText: String {
        if model.isRunning {
            return model.inProgressStatus
        }
        if let summary = model.lastSummary {
            return model.doneStatus(summary)
        }
        if let message = model.statusMessage {
            return message
        }
        if let reason = model.convertDisabledReason {
            return reason
        }
        return "Ready"
    }

    @ViewBuilder
    private var statusMark: some View {
        if model.isRunning {
            YellowSpinner()
        } else if model.lastSummary != nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.green)
                .accessibilityLabel("Done")
        } else {
            Color.clear
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .frame(width: 920, height: 700)
}
