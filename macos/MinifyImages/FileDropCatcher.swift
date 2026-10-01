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

    /// Finder still publishes this for folder drags.
    private static let filenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerDropTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerDropTypes()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender) else { return [] }
        coordinator?.isTargeted.wrappedValue = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        accepts(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        coordinator?.isTargeted.wrappedValue = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        coordinator?.isTargeted.wrappedValue = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        accepts(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        coordinator?.isTargeted.wrappedValue = false
        let urls = readURLs(from: sender)
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async {
            self.coordinator?.onDrop(urls)
        }
        return true
    }

    private func registerDropTypes() {
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(UTType.folder.identifier),
            NSPasteboard.PasteboardType(UTType.directory.identifier),
            Self.filenamesPasteboardType,
        ])
    }

    private func accepts(_ sender: NSDraggingInfo) -> Bool {
        let types = sender.draggingPasteboard.types ?? []
        if types.contains(.fileURL) || types.contains(Self.filenamesPasteboardType) {
            return true
        }
        let folder = NSPasteboard.PasteboardType(UTType.folder.identifier)
        let directory = NSPasteboard.PasteboardType(UTType.directory.identifier)
        return types.contains(folder) || types.contains(directory)
    }

    /// File URLs and folder URLs. `urlReadingFileURLsOnly` drops directories on recent macOS.
    private func readURLs(from sender: NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        var urls: [URL] = []

        func append(_ url: URL) {
            guard url.isFileURL else { return }
            let standardized = url.standardizedFileURL
            guard !urls.contains(where: { $0.standardizedFileURL == standardized }) else { return }
            urls.append(url)
        }

        if let items = pasteboard.pasteboardItems {
            for item in items {
                if let value = item.string(forType: .fileURL), let url = Self.fileURL(from: value) {
                    append(url)
                }
            }
        }

        if let files = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            for url in files {
                append(url)
            }
        }

        // Folders are file URLs, but urlReadingFileURLsOnly drops them on recent macOS.
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in objects {
                append(url)
            }
        }

        let folderTypes = [UTType.folder.identifier, UTType.directory.identifier]
        if let folders = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingContentsConformToTypes: folderTypes]
        ) as? [URL] {
            for url in folders {
                append(url)
            }
        }

        if let paths = pasteboard.propertyList(forType: Self.filenamesPasteboardType) as? [String] {
            for path in paths {
                append(URL(fileURLWithPath: path))
            }
        }

        return urls
    }

    private static func fileURL(from string: String) -> URL? {
        if let url = URL(string: string), url.isFileURL {
            return url
        }
        if string.hasPrefix("/") {
            return URL(fileURLWithPath: string)
        }
        return nil
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

    private static let typeIdentifiers = [
        UTType.fileURL.identifier,
        UTType.folder.identifier,
        UTType.directory.identifier,
    ]

    private static func url(from provider: NSItemProvider) async -> URL? {
        for identifier in typeIdentifiers where provider.hasItemConformingToTypeIdentifier(identifier) {
            if let url = await load(provider, identifier: identifier), url.isFileURL {
                return url
            }
        }
        return nil
    }

    private static func load(_ provider: NSItemProvider, identifier: String) async -> URL? {
        if let url = await loadItem(provider, identifier: identifier) {
            return url
        }
        return await loadInPlace(provider, identifier: identifier)
    }

    private static func loadItem(_ provider: NSItemProvider, identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                continuation.resume(returning: url(from: item))
            }
        }
    }

    private static func loadInPlace(_ provider: NSItemProvider, identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: identifier) { url, inPlace, _ in
                guard inPlace, let url else {
                    continuation.resume(returning: nil)
                    return
                }
                _ = url.startAccessingSecurityScopedResource()
                continuation.resume(returning: url)
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }
}
