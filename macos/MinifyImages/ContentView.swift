import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            header
            DropZoneView()
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 20)

            if !model.jobs.isEmpty {
                Divider().opacity(0.45)
                JobListView()
            }

            Divider().opacity(0.45)
            OptionsView()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $model.isTargeted) { providers in
            Task {
                let urls = await DroppedFileLoader.urls(from: providers)
                model.addDroppedURLs(urls)
            }
            return true
        }
        .frame(minWidth: 700, idealWidth: 760, minHeight: 560, idealHeight: 640)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Minify Images")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                Text("JPEG & PNG → high-quality WebP for your blog")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerStatus
            Spacer()
            if !model.jobs.isEmpty {
                Button("Clear") {
                    model.clear()
                }
                .disabled(model.isRunning)
            }
            if model.isRunning {
                Button("Cancel") {
                    model.cancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            Button(model.isRunning ? "Converting…" : convertTitle) {
                model.convert()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canConvert)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var convertTitle: String {
        let n = model.jobs.count
        if n == 0 { return "Convert" }
        return n == 1 ? "Convert 1 image" : "Convert \(n) images"
    }

    @ViewBuilder
    private var footerStatus: some View {
        if let summary = model.lastSummary {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: summary.failed == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(summary.failed == 0 ? Color.green : Color.orange)
                    Text(summaryLine(summary))
                        .font(.system(size: 12.5, weight: .medium))
                    if summary.converted > 0 {
                        Button("Show in Finder") {
                            model.revealOutputs()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.tint)
                    }
                }
                Text(summary.destinationNote)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        } else if let reason = model.convertDisabledReason, !model.isRunning {
            Text(reason)
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        } else if model.isRunning {
            let done = model.completedCount + model.failedCount
            Text("Converting \(min(done + 1, model.jobs.count)) of \(model.jobs.count)…")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }

    private func summaryLine(_ summary: RunSummary) -> String {
        var parts: [String] = []
        if summary.converted > 0 {
            parts.append("\(summary.converted) converted")
            parts.append("\(ByteFormat.string(summary.totalIn)) → \(ByteFormat.string(summary.totalOut)) (\(ByteFormat.savings(from: summary.totalIn, to: summary.totalOut)))")
        }
        if summary.failed > 0 {
            parts.append("\(summary.failed) failed")
        }
        if parts.isEmpty {
            return "Nothing converted"
        }
        return parts.joined(separator: "  ·  ")
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .frame(width: 760, height: 640)
}
