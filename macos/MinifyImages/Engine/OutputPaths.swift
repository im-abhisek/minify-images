import Foundation

enum OutputPaths {
    static func webpURL(for source: URL, root: URL, outDir: URL?) -> URL {
        let base = source.deletingPathExtension().lastPathComponent + ".webp"
        guard let outDir else {
            return source.deletingLastPathComponent().appendingPathComponent(base)
        }

        let sourceDir = source.deletingLastPathComponent()
        let relativeDir = relativePath(from: root, to: sourceDir)
        if relativeDir.isEmpty {
            return outDir.appendingPathComponent(base)
        }
        return outDir.appendingPathComponent(relativeDir).appendingPathComponent(base)
    }

    static func relativePath(from root: URL, to directory: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let dirPath = directory.standardizedFileURL.path
        if dirPath == rootPath { return "" }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard dirPath.hasPrefix(prefix) else { return "" }
        return String(dirPath.dropFirst(prefix.count))
    }
}
