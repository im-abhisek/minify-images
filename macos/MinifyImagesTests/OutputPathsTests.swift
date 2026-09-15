import XCTest
@testable import MinifyImages

final class OutputPathsTests: XCTestCase {
    func testDefaultOutputSitsNextToOriginal() {
        let source = URL(fileURLWithPath: "/blog/drafts/hero.jpg")
        let root = URL(fileURLWithPath: "/blog/drafts")
        let dest = OutputPaths.webpURL(for: source, root: root, outDir: nil)
        XCTAssertEqual(dest.path, "/blog/drafts/hero.webp")
    }

    func testChosenFolderPreservesRelativeDirectories() {
        let source = URL(fileURLWithPath: "/blog/drafts/nested/hero.jpg")
        let root = URL(fileURLWithPath: "/blog/drafts")
        let out = URL(fileURLWithPath: "/tmp/out")
        let dest = OutputPaths.webpURL(for: source, root: root, outDir: out)
        XCTAssertEqual(dest.path, "/tmp/out/nested/hero.webp")
    }

    func testChosenFolderWithFileDropUsesBasenameOnly() {
        let source = URL(fileURLWithPath: "/photos/hero.jpg")
        let root = URL(fileURLWithPath: "/photos")
        let out = URL(fileURLWithPath: "/tmp/out")
        let dest = OutputPaths.webpURL(for: source, root: root, outDir: out)
        XCTAssertEqual(dest.path, "/tmp/out/hero.webp")
    }
}
