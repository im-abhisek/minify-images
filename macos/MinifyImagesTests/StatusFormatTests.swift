import XCTest
@testable import MinifyImages

final class StatusFormatTests: XCTestCase {
    func testStatusSizeUsesOneDecimal() {
        XCTAssertEqual(ByteFormat.statusSize(500), "500 B")
        XCTAssertEqual(ByteFormat.statusSize(1024), "1.0 KB")
        XCTAssertEqual(ByteFormat.statusSize(7_340_032), "7.0 MB")
        let eighteenFour = Int((18.4 * 1024 * 1024).rounded())
        XCTAssertEqual(ByteFormat.statusSize(eighteenFour), "18.4 MB")
    }

    func testSavedPercentRoundsLikeTheStatusBar() {
        XCTAssertEqual(ByteFormat.savedPercent(from: 100, to: 38), 62)
        XCTAssertEqual(ByteFormat.savedPercent(from: 0, to: 0), 0)
        let source = Int((18.4 * 1024 * 1024).rounded())
        let dest = 7_340_032
        XCTAssertEqual(ByteFormat.savedPercent(from: source, to: dest), 62)
    }
}
