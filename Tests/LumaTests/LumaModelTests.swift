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
        XCTAssertEqual(adjustments.radialExposure, 0)
        XCTAssertEqual(adjustments.radialCenterX, 0.5)
        XCTAssertEqual(adjustments.radialCenterY, 0.5)
        XCTAssertEqual(adjustments.radialRadius, 0.35)
        XCTAssertEqual(adjustments.radialFeather, 0.25)
        XCTAssertFalse(adjustments.radialInvert)
        XCTAssertEqual(adjustments.linearExposure, 0)
        XCTAssertEqual(adjustments.linearStartY, 1)
        XCTAssertEqual(adjustments.linearEndY, 0.65)
        XCTAssertFalse(adjustments.linearInvert)
        XCTAssertEqual(adjustments.spotHealAmount, 0)
        XCTAssertEqual(adjustments.spotHealX, 0.5)
        XCTAssertEqual(adjustments.spotHealY, 0.5)
        XCTAssertEqual(adjustments.spotHealRadius, 0.06)
        XCTAssertEqual(adjustments.spotHealFeather, 0.04)
        XCTAssertEqual(adjustments.spotHealSourceOffsetX, 0.08)
        XCTAssertEqual(adjustments.spotHealSourceOffsetY, 0)
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

    func testLinearGradientDirectionCanBeInverted() {
        var adjustments = PhotoAdjustments(linearStartY: 0.9, linearEndY: 0.25)

        adjustments.invertLinearGradientDirection()

        XCTAssertEqual(adjustments.linearStartY, 0.25)
        XCTAssertEqual(adjustments.linearEndY, 0.9)
    }

    func testBlackAndWhiteLookPreservesStrongerExistingToneAdjustments() {
        var adjustments = PhotoAdjustments(
            contrast: 1.4,
            saturation: 1.2,
            vibrance: 0.3,
            clarity: 0.5,
            vignette: 0.4
        )

        adjustments.applyBlackAndWhiteLook()

        XCTAssertEqual(adjustments.saturation, 0)
        XCTAssertEqual(adjustments.vibrance, 0)
        XCTAssertEqual(adjustments.contrast, 1.4)
        XCTAssertEqual(adjustments.clarity, 0.5)
        XCTAssertEqual(adjustments.blacks, -0.08)
        XCTAssertEqual(adjustments.whites, 0.08)
        XCTAssertEqual(adjustments.vignette, 0.4)
    }

    func testCropTransformCanBeResetWithoutChangingToneAdjustments() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            straighten: 12,
            rotationTurns: 1,
            cropAspect: .square
        )

        adjustments.resetCropTransform()

        XCTAssertEqual(adjustments.exposure, 0.6)
        XCTAssertEqual(adjustments.straighten, 0)
        XCTAssertEqual(adjustments.rotationTurns, 0)
        XCTAssertEqual(adjustments.cropAspect, .original)
    }

    func testToneAdjustmentsCanBeResetWithoutChangingCropOrLocalAdjustments() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            contrast: 1.4,
            saturation: 0.7,
            warmth: 250,
            radialExposure: -0.5,
            straighten: 12,
            cropAspect: .square
        )

        adjustments.resetToneAdjustments()

        XCTAssertEqual(adjustments.exposure, 0)
        XCTAssertEqual(adjustments.contrast, 1)
        XCTAssertEqual(adjustments.saturation, 1)
        XCTAssertEqual(adjustments.warmth, 0)
        XCTAssertEqual(adjustments.radialExposure, -0.5)
        XCTAssertEqual(adjustments.straighten, 12)
        XCTAssertEqual(adjustments.cropAspect, .square)
    }

    func testLibrarySortMetadata() {
        XCTAssertEqual(LibrarySort.allCases.map(\.rawValue), ["File Name", "Capture Date", "Rating", "Flag"])
    }

    func testLibraryFilterMetadata() {
        XCTAssertEqual(LibraryFilter.allCases.map(\.rawValue), ["All", "Picked", "Rejected", "Rated", "Unrated", "Unflagged", "Edited", "Unedited"])
    }

    func testExportPresetSettings() {
        XCTAssertEqual(ExportPreset.fullSize.jpegQuality, 0.95)
        XCTAssertEqual(ExportPreset.fullSize.longEdge, 0)
        XCTAssertEqual(ExportPreset.largeWeb.longEdge, 2560)
        XCTAssertEqual(ExportPreset.social.longEdge, 1600)
        XCTAssertEqual(ExportPreset.thumbnail.longEdge, 800)
    }

    func testExportFormatMetadata() {
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ExportFormat.jpeg.typeIdentifier, "public.jpeg")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportFormat.png.typeIdentifier, "public.png")
    }
}
