import UniformTypeIdentifiers
import XCTest
@testable import MinifyImages

final class ImageDecoderTests: XCTestCase {
    func testHeicAndHeifMapToHeicKind() throws {
        XCTAssertEqual(try ImageDecoder.sourceKind(for: UTType.heic.identifier, fallbackExtension: ""), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: UTType.heif.identifier, fallbackExtension: ""), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: "public.heic", fallbackExtension: "dat"), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: "public.heif", fallbackExtension: "dat"), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: "com.example.unknown", fallbackExtension: "HEIC"), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: "com.example.unknown", fallbackExtension: "heif"), .heic)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: UTType.jpeg.identifier, fallbackExtension: ""), .jpeg)
        XCTAssertEqual(try ImageDecoder.sourceKind(for: UTType.png.identifier, fallbackExtension: ""), .png)
        XCTAssertThrowsError(try ImageDecoder.sourceKind(for: "public.data", fallbackExtension: "txt"))
    }
}
