import XCTest
@testable import Luma

final class LumaModelTests: XCTestCase {
    func testPhotoAdjustmentsDecodeLegacyCatalogDefaultsNewFields() throws {
        let data = """
        {
          "exposure": 0.4,
          "contrast": 1.2,
          "saturation": 0.9,
          "warmth": 120,
          "rotationTurns": 1
        }
        """.data(using: .utf8)!

        let adjustments = try JSONDecoder().decode(PhotoAdjustments.self, from: data)

        XCTAssertEqual(adjustments.exposure, 0.4)
        XCTAssertEqual(adjustments.contrast, 1.2)
        XCTAssertEqual(adjustments.saturation, 0.9)
        XCTAssertEqual(adjustments.warmth, 120)
        XCTAssertEqual(adjustments.rotationTurns, 1)
        XCTAssertEqual(adjustments.highlights, 0)
        XCTAssertEqual(adjustments.shadows, 0)
        XCTAssertEqual(adjustments.cropAspect, .original)
        XCTAssertEqual(adjustments.colorMixer, ColorMixerAdjustments())
        XCTAssertEqual(adjustments.beautySmooth, 0)
        XCTAssertEqual(adjustments.beautyWrinkle, 0)
        XCTAssertEqual(adjustments.beautyBlemish, 0)
        XCTAssertEqual(adjustments.beautyWhiten, 0)
        XCTAssertEqual(adjustments.beautyRosy, 0)
        XCTAssertEqual(adjustments.beautySoften, 0)
        XCTAssertEqual(adjustments.eyeEnlarge, 0)
        XCTAssertEqual(adjustments.faceSlim, 0)
        XCTAssertEqual(adjustments.bodySlim, 0)
    }

    func testCropAspectRatios() {
        XCTAssertNil(CropAspect.original.ratio)
        XCTAssertEqual(CropAspect.square.ratio, 1)
        XCTAssertEqual(CropAspect.portrait.ratio, 0.8)
        XCTAssertEqual(CropAspect.classic.ratio, 1.5)
        XCTAssertEqual(CropAspect.wide.ratio, 16.0 / 9.0)
    }

    func testColorMixerDetectsAdjustments() {
        XCTAssertFalse(ColorMixerAdjustments().hasAdjustments)

        var mixer = ColorMixerAdjustments()
        mixer.blue = -0.35

        XCTAssertTrue(mixer.hasAdjustments)
    }

    func testLibrarySortMetadata() {
        XCTAssertEqual(LibrarySort.allCases.map(\.rawValue), ["File Name", "Capture Date", "Rating", "Flag"])
    }

    func testLibraryFilterMetadata() {
        XCTAssertEqual(LibraryFilter.allCases.map(\.rawValue), ["All", "Picked", "Rejected", "Rated", "Unrated"])
    }

    func testExportPresetSettings() {
        XCTAssertEqual(ExportPreset.fullSize.jpegQuality, 0.95)
        XCTAssertEqual(ExportPreset.fullSize.longEdge, 0)
        XCTAssertEqual(ExportPreset.largeWeb.longEdge, 2560)
        XCTAssertEqual(ExportPreset.social.longEdge, 1600)
        XCTAssertEqual(ExportPreset.thumbnail.longEdge, 800)
    }
}
