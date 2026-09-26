import CoreGraphics
import Foundation
import ImageIO

struct ThumbnailRecord {
    var byteCount: Int
    var image: CGImage?
}

/// Downsamples previews off the main thread and keeps them for the session.
final class ThumbnailStore: @unchecked Sendable {
    static let shared = ThumbnailStore()

    private let lock = NSLock()
    private var cache: [String: ThumbnailRecord] = [:]
    private var inflight: [String: Task<Void, Never>] = [:]

    func record(for path: String) -> ThumbnailRecord? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.cache[path]
    }

    func ensureLoaded(url: URL) async {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        if self.record(for: path) != nil { return }
        let task = self.startTask(url: url, path: path)
        await task.value
    }

    private func startTask(url: URL, path: String) -> Task<Void, Never> {
        self.lock.lock()
        if self.cache[path] != nil {
            self.lock.unlock()
            return Task {}
        }
        if let existing = self.inflight[path] {
            self.lock.unlock()
            return existing
        }
        let task = Task.detached(priority: .utility) {
            let made = ThumbnailMaker.make(url: url)
            ThumbnailStore.shared.finish(made, path: path)
        }
        self.inflight[path] = task
        self.lock.unlock()
        return task
    }

    fileprivate func finish(_ record: ThumbnailRecord, path: String) {
        self.lock.lock()
        self.cache[path] = record
        self.inflight[path] = nil
        self.lock.unlock()
    }
}

private enum ThumbnailMaker {
    static func make(url: URL) -> ThumbnailRecord {
        ThumbnailRecord(byteCount: fileSize(url), image: downsample(url: url, maxPixel: 300))
    }

    private static func fileSize(_ url: URL) -> Int {
        let raw = try? FileManager.default.attributesOfItem(atPath: url.path)[.size]
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        return 0
    }

    private static func downsample(url: URL, maxPixel: Int) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    }
}
