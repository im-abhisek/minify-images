import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    var droppedInputs: [URL] = []
    var jobs: [ImageJob] = []
    var isTargeted = false
    var quality = 75
    var pngStrategy: PNGStrategy = .preserve
    var outputMode: OutputMode = .besideOriginals
    var outputFolder: URL?
    var isRunning = false
    var skippedNotice: String?
    var statusMessage: String?
    var lastSummary: RunSummary?
    private(set) var runningQuality = 75

    private var runningTask: Task<Void, Never>?
    private var isPresentingPanel = false
    private var scopedInputs: [URL] = []
    private var scopedOutputURL: URL?

    private enum Store {
        static let bookmark = "minify.outputFolderBookmark"
        static let path = "minify.outputFolderPath"
        static let useFolder = "minify.outputUsesFolder"
    }

    init() {
        restoreOutputFolder()
    }

    var settings: ConversionSettings {
        ConversionSettings(
            quality: quality,
            maxDimension: nil,
            pngStrategy: pngStrategy,
            outputFolder: outputMode == .folder ? outputFolder : nil
        )
    }

    var canConvert: Bool {
        !jobs.isEmpty && !isRunning && (outputMode == .besideOriginals || outputFolder != nil)
    }

    var convertDisabledReason: String? {
        if jobs.isEmpty { return "Drop JPEG or PNG files to convert" }
        if outputMode == .folder && outputFolder == nil { return "Choose an output folder" }
        return nil
    }

    var outputFolderDisplay: String? {
        guard outputMode == .folder, let outputFolder else { return nil }
        return outputFolder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var inProgressStatus: String {
        let total = jobs.count
        guard total > 0 else { return "In progress · Quality \(runningQuality)" }
        let finished = completedCount + failedCount
        let current = min(finished + 1, total)
        return "In progress · Quality \(runningQuality) · (\(current)/\(total))"
    }

    func doneStatus(_ summary: RunSummary) -> String {
        if summary.totalIn <= 0 {
            if summary.failed > 0 {
                return "Done · \(summary.failed == 1 ? "1 failed" : "\(summary.failed) failed")"
            }
            return "Done"
        }
        let percent = ByteFormat.savedPercent(from: summary.totalIn, to: summary.totalOut)
        let sizes = "\(ByteFormat.statusSize(summary.totalIn)) to \(ByteFormat.statusSize(summary.totalOut))"
        var line = "Done · Saved \(percent)% (\(sizes))"
        if summary.failed > 0 {
            line += summary.failed == 1 ? " · 1 failed" : " · \(summary.failed) failed"
        }
        return line
    }

    var completedCount: Int {
        jobs.filter { if case .succeeded = $0.status { return true }; return false }.count
    }

    var failedCount: Int {
        jobs.filter { if case .failed = $0.status { return true }; return false }.count
    }

    var convertingCount: Int {
        jobs.filter { $0.status == .converting }.count
    }

    func addDroppedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        var merged = droppedInputs
        for url in urls {
            retainScope(url)
            let standardized = url.resolvingSymlinksInPath().standardizedFileURL
            if standardized.path != url.standardizedFileURL.path {
                retainScope(standardized)
            }
            if !merged.contains(where: { $0.standardizedFileURL == standardized }) {
                merged.append(standardized)
            }
        }
        droppedInputs = merged
        refreshJobs(resetResults: true)
    }

    /// Ignores the request while a batch is running so the in-progress count stays on the original list.
    func removeJob(id: UUID) {
        guard !isRunning else { return }
        jobs.removeAll { $0.id == id }
        droppedInputs = jobs.map(\.source)
        if jobs.isEmpty {
            skippedNotice = nil
        }
        lastSummary = nil
        statusMessage = nil
    }

    func refreshJobs(resetResults: Bool) {
        let previous: [String: ImageJob] = resetResults ? [:] : Dictionary(
            uniqueKeysWithValues: jobs.map { ($0.source.standardizedFileURL.path, $0) }
        )
        let collected = ImageCollector.collectDropped(urls: droppedInputs, recursive: true)
        jobs = collected.images.map { item in
            if let existing = previous[item.source.standardizedFileURL.path], !resetResults {
                return ImageJob(id: existing.id, source: item.source, root: item.root, status: existing.status)
            }
            return ImageJob(source: item.source, root: item.root)
        }
        if collected.skipped > 0 {
            skippedNotice = collected.skipped == 1
                ? "Skipped 1 item that wasn’t JPEG or PNG"
                : "Skipped \(collected.skipped) items that weren’t JPEG or PNG"
        } else {
            skippedNotice = nil
        }
        lastSummary = nil
        statusMessage = nil
    }

    func chooseFiles() {
        guard !isPresentingPanel else { return }
        isPresentingPanel = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                defer { self.isPresentingPanel = false }
                self.presentFilePanel()
            }
        }
    }

    func chooseOutputFolder(revertIfCancelled: Bool = false) {
        guard !isPresentingPanel else { return }
        isPresentingPanel = true
        let revert = revertIfCancelled
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                defer { self.isPresentingPanel = false }
                self.presentOutputFolderPanel(revertIfCancelled: revert)
            }
        }
    }

    func rememberOutputMode() {
        UserDefaults.standard.set(outputMode == .folder, forKey: Store.useFolder)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealOutputs() {
        let urls = jobs.compactMap { job -> URL? in
            if case .succeeded(let result) = job.status { return result.destination }
            return nil
        }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func clear() {
        cancel()
        releaseInputScopes()
        droppedInputs = []
        jobs = []
        skippedNotice = nil
        statusMessage = nil
        lastSummary = nil
    }

    func cancel() {
        let wasRunning = isRunning
        runningTask?.cancel()
        runningTask = nil
        isRunning = false
        for index in jobs.indices {
            if jobs[index].status == .converting {
                jobs[index].status = .queued
            }
        }
        if wasRunning {
            statusMessage = "Cancelled"
        }
    }

    func convert() {
        guard canConvert else { return }
        ensureOutputAccess()
        cancel()
        isRunning = true
        runningQuality = quality
        lastSummary = nil
        statusMessage = nil
        for index in jobs.indices {
            jobs[index].status = .queued
        }

        let snapshot = jobs
        let currentSettings = settings
        runningTask = Task.detached(priority: .userInitiated) { [weak self] in
            var totalIn = 0
            var totalOut = 0
            var wrote = 0
            var failed = 0

            for job in snapshot {
                guard !Task.isCancelled else { break }
                await self?.markConverting(id: job.id)
                do {
                    let result = try ConversionService.convert(
                        source: job.source,
                        root: job.root,
                        settings: currentSettings
                    )
                    totalIn += result.sourceBytes
                    totalOut += result.destBytes
                    wrote += 1
                    await self?.markSucceeded(id: job.id, result: result)
                } catch is CancellationError {
                    break
                } catch {
                    failed += 1
                    await self?.markFailed(id: job.id, message: error.localizedDescription)
                }
            }

            await self?.finishRun(wrote: wrote, failed: failed, totalIn: totalIn, totalOut: totalOut, cancelled: Task.isCancelled)
        }
    }

    private func presentFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .folder]
        panel.message = "Add JPEG or PNG images, or a folder of them"
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        addDroppedURLs(panel.urls)
    }

    /// Directories only. Deferred off the SwiftUI click so the panel actually appears.
    private func presentOutputFolderPanel(revertIfCancelled: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "WebP files will be written here"
        panel.directoryURL = outputFolder
        guard panel.runModal() == .OK, let url = panel.url else {
            if revertIfCancelled, outputFolder == nil {
                outputMode = .besideOriginals
            }
            return
        }
        adoptOutputFolder(url)
    }

    private func adoptOutputFolder(_ url: URL) {
        releaseOutputAccess()
        if url.startAccessingSecurityScopedResource() {
            scopedOutputURL = url
        }
        outputFolder = url
        outputMode = .folder
        persistOutputFolder(url)
    }

    private func ensureOutputAccess() {
        guard outputMode == .folder, let outputFolder else { return }
        guard scopedOutputURL == nil else { return }
        if outputFolder.startAccessingSecurityScopedResource() {
            scopedOutputURL = outputFolder
        }
    }

    private func releaseOutputAccess() {
        scopedOutputURL?.stopAccessingSecurityScopedResource()
        scopedOutputURL = nil
    }

    private func retainScope(_ url: URL) {
        let key = url.standardizedFileURL
        guard !scopedInputs.contains(where: { $0.standardizedFileURL == key }) else { return }
        if url.startAccessingSecurityScopedResource() {
            scopedInputs.append(url)
        }
    }

    private func releaseInputScopes() {
        for url in scopedInputs {
            url.stopAccessingSecurityScopedResource()
        }
        scopedInputs.removeAll()
    }

    private func persistOutputFolder(_ url: URL) {
        let defaults = UserDefaults.standard
        defaults.set(url.path, forKey: Store.path)
        defaults.set(true, forKey: Store.useFolder)
        if let data = bookmarkData(for: url) {
            defaults.set(data, forKey: Store.bookmark)
        }
    }

    private func restoreOutputFolder() {
        let defaults = UserDefaults.standard
        let useFolder = defaults.bool(forKey: Store.useFolder)
        let resolved: URL?
        if let data = defaults.data(forKey: Store.bookmark) {
            resolved = resolveBookmark(data)
        } else if let path = defaults.string(forKey: Store.path) {
            resolved = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            resolved = nil
        }
        guard let resolved else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return }
        if resolved.startAccessingSecurityScopedResource() {
            scopedOutputURL = resolved
        }
        outputFolder = resolved
        if useFolder {
            outputMode = .folder
        }
    }

    private func bookmarkData(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) {
            if stale { persistOutputFolder(url) }
            return url
        }
        stale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) {
            if stale { persistOutputFolder(url) }
            return url
        }
        return nil
    }

    private func markConverting(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = .converting
    }

    private func markSucceeded(id: UUID, result: ConversionResult) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = .succeeded(result)
    }

    private func markFailed(id: UUID, message: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = .failed(message)
    }

    private func finishRun(wrote: Int, failed: Int, totalIn: Int, totalOut: Int, cancelled: Bool) {
        isRunning = false
        runningTask = nil
        if cancelled {
            statusMessage = "Cancelled"
            return
        }
        let whereText: String
        if let folder = settings.outputFolder {
            whereText = "Saved to \(folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))"
        } else {
            whereText = "Saved next to the originals"
        }
        lastSummary = RunSummary(
            converted: wrote,
            failed: failed,
            totalIn: totalIn,
            totalOut: totalOut,
            destinationNote: whereText
        )
    }
}

struct ImageJob: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: URL
    let root: URL
    var status: JobStatus

    init(id: UUID = UUID(), source: URL, root: URL, status: JobStatus = .queued) {
        self.id = id
        self.source = source
        self.root = root
        self.status = status
    }

    var name: String { source.lastPathComponent }
}

enum JobStatus: Equatable, Sendable {
    case queued
    case converting
    case succeeded(ConversionResult)
    case failed(String)
}

enum OutputMode: String, CaseIterable, Identifiable {
    case besideOriginals
    case folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .besideOriginals: return "Originals"
        case .folder: return "Choose"
        }
    }
}

struct RunSummary: Equatable {
    var converted: Int
    var failed: Int
    var totalIn: Int
    var totalOut: Int
    var destinationNote: String
}
