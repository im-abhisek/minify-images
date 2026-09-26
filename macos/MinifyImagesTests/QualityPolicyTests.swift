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

    func testHEICUsesPhotoQualityAndKeepsAlpha() {
        let opaque = QualityPolicy.recipe(
            kind: .heic,
            hasAlpha: false,
            quality: 75,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(opaque, .photo(quality: 75))
        XCTAssertEqual(opaque.label(hasAlpha: false), "photo, q75")

        let withAlpha = QualityPolicy.recipe(
            kind: .heic,
            hasAlpha: true,
            quality: 75,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(withAlpha, .photo(quality: 75))
        XCTAssertEqual(withAlpha.label(hasAlpha: true), "photo+alpha, q75")
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

    func testQualityZeroAndHundredPassThrough() {
        let low = QualityPolicy.recipe(
            kind: .jpeg,
            hasAlpha: false,
            quality: 0,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(low, .photo(quality: 0))

        let high = QualityPolicy.recipe(
            kind: .jpeg,
            hasAlpha: false,
            quality: 100,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(high, .photo(quality: 100))

        let opaquePNG = QualityPolicy.recipe(
            kind: .png,
            hasAlpha: false,
            quality: 0,
            lossless: false,
            photo: false
        )
        XCTAssertEqual(opaquePNG, .nearLossless(quality: 0))
    }

    func testQualityClampsToLibwebpRangeWithoutRaisingZero() {
        XCTAssertEqual(QualityPolicy.clampedQuality(0), 0)
        XCTAssertEqual(QualityPolicy.clampedQuality(75), 75)
        XCTAssertEqual(QualityPolicy.clampedQuality(100), 100)
        XCTAssertEqual(QualityPolicy.clampedQuality(-4), 0)
        XCTAssertEqual(QualityPolicy.clampedQuality(140), 100)
    }

    func testSettingsPreserveMapsToCLIDefaults() {
        let settings = ConversionSettings()
        XCTAssertEqual(settings.quality, 90)
        XCTAssertNil(settings.maxDimension)
        XCTAssertFalse(settings.lossless)
        XCTAssertFalse(settings.photo)
    }
}
