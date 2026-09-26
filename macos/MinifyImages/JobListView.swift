import AppKit
import SwiftUI

struct JobTileView: View {
    @Environment(AppModel.self) private var model
    let job: ImageJob

    @State private var preview: NSImage?
    @State private var byteCount: Int?
    @State private var isHovering = false
    @FocusState private var removeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
            Text(job.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(captionColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            self.isHovering = hovering
        }
        .task(id: self.job.source) {
            await self.loadThumbnail()
        }
        .contextMenu {
            Button("Reveal original in Finder") {
                self.model.reveal(self.job.source)
            }
            if case .succeeded(let result) = self.job.status {
                Button("Reveal WebP in Finder") {
                    self.model.reveal(result.destination)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.38)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let preview {
                        Image(nsImage: preview)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay {
                    if case .converting = job.status {
                        ZStack {
                            Color.black.opacity(0.28)
                            YellowSpinner(side: 16)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if case .succeeded = job.status {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .shadow(color: Color.black.opacity(0.35), radius: 1, y: 0.5)
                            .padding(5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel(job.name)

            removeButton
                .padding(6)
        }
        .frame(maxWidth: .infinity)
    }

    private var removeButton: some View {
        Button {
            self.model.removeJob(id: self.job.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(self.model.isRunning ? 0.55 : 1))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .opacity(self.showsRemove ? (self.model.isRunning ? 0.45 : 1) : 0)
        .allowsHitTesting(self.showsRemove)
        .disabled(self.model.isRunning)
        .focused(self.$removeFocused)
        .help(self.model.isRunning ? "Wait until conversion finishes" : "Remove")
        .accessibilityLabel("Remove \(job.name)")
    }

    private var showsRemove: Bool {
        self.isHovering || self.removeFocused
    }

    private var caption: String {
        switch job.status {
        case .succeeded(let result):
            let saved = ByteFormat.savings(from: result.sourceBytes, to: result.destBytes)
            return "\(Self.sizeText(result.sourceBytes)) to \(Self.sizeText(result.destBytes)) · \(saved)"
        case .failed(let message):
            return message
        case .queued, .converting:
            if let byteCount {
                return Self.sizeText(byteCount)
            }
            return "…"
        }
    }

    private var captionColor: Color {
        switch job.status {
        case .succeeded(let result):
            return result.destBytes > result.sourceBytes ? .yellow : .green
        case .failed:
            return .red
        case .queued, .converting:
            return .secondary
        }
    }

    private func loadThumbnail() async {
        let url = self.job.source
        await ThumbnailStore.shared.ensureLoaded(url: url)
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard let record = ThumbnailStore.shared.record(for: path) else { return }
        self.byteCount = record.byteCount
        if let image = record.image {
            self.preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
    }

    /// "2.4 MB", "610 KB", "1.5 KB", or "820 B".
    private static func sizeText(_ bytes: Int) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        if bytes >= 1024 * 1024 {
            return String(format: "%.1f MB", locale: posix, Double(bytes) / (1024 * 1024))
        }
        if bytes >= 1024 {
            let kb = Double(bytes) / 1024
            if kb >= 10 {
                return String(format: "%.0f KB", locale: posix, kb)
            }
            return String(format: "%.1f KB", locale: posix, kb)
        }
        return "\(bytes) B"
    }
}
