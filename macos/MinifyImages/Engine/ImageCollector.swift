import Foundation
import UniformTypeIdentifiers

struct CollectedImage: Equatable, Sendable {
    let source: URL
    let root: URL
}

enum ImageCollector {
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]

    static func collect(inputs: [URL], recursive: Bool) throws -> [CollectedImage] {
        var found: [CollectedImage] = []
        for input in inputs {
            let url = input.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw CollectorError.notFound(url)
            }
            if isDirectory.boolValue {
                found.append(contentsOf: try walk(directory: url, root: url, recursive: recursive))
            } else if isImageFile(url) {
                found.append(CollectedImage(source: url, root: url.deletingLastPathComponent()))
            } else {
                throw CollectorError.notAnImage(url)
            }
        }

        var unique: [CollectedImage] = []
        var seen = Set<String>()
        for item in found {
            let key = item.source.standardizedFileURL.path
            if seen.contains(key) { continue }
            seen.insert(key)
            unique.append(item)
        }
        unique.sort { $0.source.path.localizedStandardCompare($1.source.path) == .orderedAscending }
        return unique
    }

    /// Dropped mixed selections: keep JPEG/PNG, skip anything else without failing the batch.
    static func collectDropped(urls: [URL], recursive: Bool) -> (images: [CollectedImage], skipped: Int) {
        var images: [CollectedImage] = []
        var skipped = 0
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                skipped += 1
                continue
            }
            if isDirectory.boolValue {
                do {
                    images.append(contentsOf: try walk(directory: url, root: url, recursive: recursive))
                } catch {
                    skipped += 1
                }
            } else if isImageFile(url) {
                images.append(CollectedImage(source: url, root: url.deletingLastPathComponent()))
            } else {
                skipped += 1
            }
        }

        var unique: [CollectedImage] = []
        var seen = Set<String>()
        for item in images {
            let key = item.source.standardizedFileURL.path
            if seen.contains(key) { continue }
            seen.insert(key)
            unique.append(item)
        }
        unique.sort { $0.source.path.localizedStandardCompare($1.source.path) == .orderedAscending }
        return (unique, skipped)
    }

    static func isImageFile(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    static func isSupportedType(_ type: UTType) -> Bool {
        type.conforms(to: .jpeg) || type.conforms(to: .png) || type == .folder
    }

    private static func walk(directory: URL, root: URL, recursive: Bool) throws -> [CollectedImage] {
        var found: [CollectedImage] = []
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for entry in contents {
            if entry.lastPathComponent.hasPrefix(".") { continue }
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if recursive {
                    found.append(contentsOf: try walk(directory: entry, root: root, recursive: true))
                }
                continue
            }
            if values.isRegularFile == true, isImageFile(entry) {
                found.append(CollectedImage(source: entry, root: root))
            }
        }
        return found
    }

    enum CollectorError: LocalizedError {
        case notFound(URL)
        case notAnImage(URL)

        var errorDescription: String? {
            switch self {
            case .notFound(let url):
                return "Not found: \(url.lastPathComponent)"
            case .notAnImage(let url):
                return "Not a JPEG or PNG: \(url.lastPathComponent)"
            }
        }
    }
}
