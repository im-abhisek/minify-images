import XCTest
@testable import MinifyImages

final class QualityPolicyTests: XCTestCase {
    func testJPEGDefaultIsPhotoQuality90() {
        let recipe = QualityPolicy.recipe(
            kind: .jpeg,
            hasAlpha: false,
            quality: 90,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(recipe, .photo(quality: 90))
        XCTAssertEqual(recipe.label(hasAlpha: false), "photo, q90")
    }

    func testTransparentPNGIsLosslessWithExact() {
        let recipe = QualityPolicy.recipe(
            kind: .png,
            hasAlpha: true,
            quality: 90,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(recipe, .lossless(exact: true))
        XCTAssertEqual(recipe.label(hasAlpha: true), "png+alpha, lossless")
    }

    func testOpaquePNGIsNearLossless() {
        let recipe = QualityPolicy.recipe(
            kind: .png,
            hasAlpha: false,
            quality: 90,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(recipe, .nearLossless(quality: 90))
        XCTAssertEqual(recipe.label(hasAlpha: false), "png, near-lossless q90")
    }

    func testPhotoFlagTreatsPNGAsPhotoAndKeepsAlpha() {
        let recipe = QualityPolicy.recipe(
            kind: .png,
            hasAlpha: true,
            quality: 80,
            lossless: false,
            photo: true
        )
        XCTAssertEqual(recipe, .photo(quality: 80))
        XCTAssertEqual(recipe.label(hasAlpha: true), "photo+alpha, q80")
    }

    func testLosslessFlagWinsForJPEG() {
        let recipe = QualityPolicy.recipe(
            kind: .jpeg,
            hasAlpha: false,
            quality: 90,
            lossless: true,
            photo: false
        )
        XCTAssertEqual(recipe, .lossless(exact: false))
    }

    func testSettingsPreserveMapsToCLIDefaults() {
        let settings = ConversionSettings()
        XCTAssertEqual(settings.quality, 90)
        XCTAssertNil(settings.maxDimension)
        XCTAssertFalse(settings.lossless)
        XCTAssertFalse(settings.photo)
    }
}
