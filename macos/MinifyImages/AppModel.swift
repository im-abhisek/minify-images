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
    var quality = 90
    var maxEdge: MaxEdge = .off
    var pngStrategy: PNGStrategy = .preserve
    var includeSubfolders = false
    var outputMode: OutputMode = .besideOriginals
    var outputFolder: URL?
    var isRunning = false
    var skippedNotice: String?
    var statusMessage: String?
    var lastSummary: RunSummary?

    private var runningTask: Task<Void, Never>?

    var settings: ConversionSettings {
        ConversionSettings(
            quality: quality,
            maxDimension: maxEdge.pixels,
            pngStrategy: pngStrategy,
            includeSubfolders: includeSubfolders,
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
            let standardized = url.resolvingSymlinksInPath().standardizedFileURL
            if !merged.contains(where: { $0.standardizedFileURL == standardized }) {
                merged.append(standardized)
            }
        }
        droppedInputs = merged
        refreshJobs(resetResults: true)
    }

    func refreshJobs(resetResults: Bool) {
        let previous: [String: ImageJob] = resetResults ? [:] : Dictionary(
            uniqueKeysWithValues: jobs.map { ($0.source.standardizedFileURL.path, $0) }
        )
        let collected = ImageCollector.collectDropped(urls: droppedInputs, recursive: includeSubfolders)
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
    }

    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .folder]
        panel.message = "Choose JPEG or PNG images, or a folder of them"
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        addDroppedURLs(panel.urls)
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "WebP files will be written here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputFolder = url
        outputMode = .folder
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
        droppedInputs = []
        jobs = []
        skippedNotice = nil
        statusMessage = nil
        lastSummary = nil
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
        isRunning = false
        for index in jobs.indices {
            if jobs[index].status == .converting {
                jobs[index].status = .queued
            }
        }
    }

    func convert() {
        guard canConvert else { return }
        cancel()
        isRunning = true
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

extension ConversionResult: Equatable {}

enum OutputMode: String, CaseIterable, Identifiable {
    case besideOriginals
    case folder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .besideOriginals: return "Beside originals"
        case .folder: return "Choose folder"
        }
    }
}

enum MaxEdge: Equatable, Hashable {
    case off
    case preset(Int)
    case custom(Int)

    static let presets = [2400, 1600, 1200]

    var pixels: Int? {
        switch self {
        case .off: return nil
        case .preset(let value), .custom(let value): return value
        }
    }

    var menuTitle: String {
        switch self {
        case .off: return "Off"
        case .preset(let value), .custom(let value): return "\(value) px"
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
