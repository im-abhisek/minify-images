import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileDropCatcher: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropCatcherView {
        let view = DropCatcherView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: DropCatcherView, context: Context) {
        context.coordinator.isTargeted = $isTargeted
        context.coordinator.onDrop = onDrop
        nsView.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isTargeted: $isTargeted, onDrop: onDrop)
    }

    final class Coordinator {
        var isTargeted: Binding<Bool>
        var onDrop: ([URL]) -> Void

        init(isTargeted: Binding<Bool>, onDrop: @escaping ([URL]) -> Void) {
            self.isTargeted = isTargeted
            self.onDrop = onDrop
        }
    }
}

final class DropCatcherView: NSView {
    var coordinator: FileDropCatcher.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        coordinator?.isTargeted.wrappedValue = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        coordinator?.isTargeted.wrappedValue = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        coordinator?.isTargeted.wrappedValue = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        coordinator?.isTargeted.wrappedValue = false
        let urls = readURLs(from: sender)
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async {
            coordinator?.onDrop(urls)
        }
        return true
    }

    private func readURLs(from sender: NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true,
        ]) as? [URL] ?? []
    }
}

enum DroppedFileLoader {
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        var collected: [URL] = []
        for provider in providers {
            if let url = await url(from: provider) {
                collected.append(url)
            }
        }
        return collected
    }

    private static func url(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }
}
