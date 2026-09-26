import XCTest
@testable import MinifyImages

final class ImageCollectorTests: XCTestCase {
    func testCollectsJpegAndPngAndSkipsOtherFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minify-images-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("jpeg".utf8).write(to: dir.appendingPathComponent("hero.jpg"))
        try Data("png".utf8).write(to: dir.appendingPathComponent("logo.png"))
        try Data("nope".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try Data("jpeg".utf8).write(to: dir.appendingPathComponent("nested/inside.jpg"))

        let top = try ImageCollector.collect(inputs: [dir], recursive: false)
        XCTAssertEqual(top.map(\.source.lastPathComponent).sorted(), ["hero.jpg", "logo.png"])

        let recursive = try ImageCollector.collect(inputs: [dir], recursive: true)
        XCTAssertEqual(recursive.map(\.source.lastPathComponent).sorted(), ["hero.jpg", "inside.jpg", "logo.png"])

        let dropped = ImageCollector.collectDropped(
            urls: [dir.appendingPathComponent("hero.jpg"), dir.appendingPathComponent("notes.txt")],
            recursive: false
        )
        XCTAssertEqual(dropped.images.count, 1)
        XCTAssertEqual(dropped.skipped, 1)
    }

    func testDroppedFolderIncludesNestedJpegAndPng() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("minify-images-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data("jpeg".utf8).write(to: dir.appendingPathComponent("hero.jpg"))
        try Data("png".utf8).write(to: dir.appendingPathComponent("logo.png"))
        try Data("nope".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        let nested = dir.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("jpeg".utf8).write(to: nested.appendingPathComponent("inside.jpg"))
        let deep = nested.appendingPathComponent("deep", isDirectory: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try Data("png".utf8).write(to: deep.appendingPathComponent("again.png"))

        let dropped = ImageCollector.collectDropped(urls: [dir], recursive: true)
        XCTAssertEqual(
            dropped.images.map(\.source.lastPathComponent).sorted(),
            ["again.png", "hero.jpg", "inside.jpg", "logo.png"]
        )
        XCTAssertEqual(dropped.skipped, 0)
    }
}
