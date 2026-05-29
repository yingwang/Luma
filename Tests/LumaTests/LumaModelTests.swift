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
            cropAspect: .square,
            flipHorizontal: true,
            flipVertical: true
        )

        adjustments.resetCropTransform()

        XCTAssertEqual(adjustments.exposure, 0.6)
        XCTAssertEqual(adjustments.straighten, 0)
        XCTAssertEqual(adjustments.rotationTurns, 0)
        XCTAssertEqual(adjustments.cropAspect, .original)
        XCTAssertFalse(adjustments.flipHorizontal)
        XCTAssertFalse(adjustments.flipVertical)
    }

    func testToneAdjustmentsCanBeResetWithoutChangingCropOrLocalAdjustments() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            contrast: 1.4,
            saturation: 0.7,
            warmth: 250,
            radialExposure: -0.5,
            straighten: 12,
            cropAspect: .square,
            flipHorizontal: true
        )

        adjustments.resetToneAdjustments()

        XCTAssertEqual(adjustments.exposure, 0)
        XCTAssertEqual(adjustments.contrast, 1)
        XCTAssertEqual(adjustments.saturation, 1)
        XCTAssertEqual(adjustments.warmth, 0)
        XCTAssertEqual(adjustments.radialExposure, -0.5)
        XCTAssertEqual(adjustments.straighten, 12)
        XCTAssertEqual(adjustments.cropAspect, .square)
        XCTAssertTrue(adjustments.flipHorizontal)
    }

    func testResetRadialAdjustmentRestoresDefaultsWithoutChangingOtherEdits() {
        var adjustments = PhotoAdjustments(
            exposure: 0.5,
            radialExposure: -0.8,
            radialCenterX: 0.2,
            radialCenterY: 0.3,
            radialRadius: 0.6,
            radialFeather: 0.5,
            radialInvert: true,
            linearExposure: 0.4,
            spotHealAmount: 0.7
        )

        adjustments.resetRadialAdjustment()

        XCTAssertEqual(adjustments.radialExposure, 0)
        XCTAssertEqual(adjustments.radialCenterX, 0.5)
        XCTAssertEqual(adjustments.radialCenterY, 0.5)
        XCTAssertEqual(adjustments.radialRadius, 0.35)
        XCTAssertEqual(adjustments.radialFeather, 0.25)
        XCTAssertFalse(adjustments.radialInvert)
        XCTAssertEqual(adjustments.exposure, 0.5)
        XCTAssertEqual(adjustments.linearExposure, 0.4)
        XCTAssertEqual(adjustments.spotHealAmount, 0.7)
    }

    func testResetLinearAdjustmentRestoresDefaultsWithoutChangingOtherEdits() {
        var adjustments = PhotoAdjustments(
            linearExposure: 0.9,
            linearStartY: 0.2,
            linearEndY: 0.1,
            linearInvert: true,
            radialExposure: -0.3
        )

        adjustments.resetLinearAdjustment()

        XCTAssertEqual(adjustments.linearExposure, 0)
        XCTAssertEqual(adjustments.linearStartY, 1)
        XCTAssertEqual(adjustments.linearEndY, 0.65)
        XCTAssertFalse(adjustments.linearInvert)
        XCTAssertEqual(adjustments.radialExposure, -0.3)
    }

    func testResetSpotHealRestoresDefaultsWithoutChangingOtherEdits() {
        var adjustments = PhotoAdjustments(
            spotHealAmount: 0.8,
            spotHealX: 0.1,
            spotHealY: 0.9,
            spotHealRadius: 0.3,
            spotHealFeather: 0.2,
            spotHealSourceOffsetX: 0.4,
            spotHealSourceOffsetY: -0.4,
            radialExposure: 0.5
        )

        adjustments.resetSpotHeal()

        XCTAssertEqual(adjustments.spotHealAmount, 0)
        XCTAssertEqual(adjustments.spotHealX, 0.5)
        XCTAssertEqual(adjustments.spotHealY, 0.5)
        XCTAssertEqual(adjustments.spotHealRadius, 0.06)
        XCTAssertEqual(adjustments.spotHealFeather, 0.04)
        XCTAssertEqual(adjustments.spotHealSourceOffsetX, 0.08)
        XCTAssertEqual(adjustments.spotHealSourceOffsetY, 0)
        XCTAssertEqual(adjustments.radialExposure, 0.5)
    }

    func testResetLocalAdjustmentsClearsAllLocalEditsButKeepsToneEdits() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            contrast: 1.3,
            radialExposure: -0.7,
            radialInvert: true,
            linearExposure: 0.5,
            linearInvert: true,
            spotHealAmount: 0.9
        )

        adjustments.resetLocalAdjustments()

        XCTAssertEqual(adjustments.radialExposure, 0)
        XCTAssertFalse(adjustments.radialInvert)
        XCTAssertEqual(adjustments.linearExposure, 0)
        XCTAssertFalse(adjustments.linearInvert)
        XCTAssertEqual(adjustments.spotHealAmount, 0)
        XCTAssertEqual(adjustments.exposure, 0.6)
        XCTAssertEqual(adjustments.contrast, 1.3)
    }

    func testResetBeautyAdjustmentsClearsBeautyEditsButKeepsToneEdits() {
        var adjustments = PhotoAdjustments(
            exposure: 0.4,
            beautySmooth: 0.5,
            beautyWrinkle: 0.4,
            beautyBlemish: 0.3,
            beautyBrighten: 0.2,
            beautyWhiten: 0.3,
            beautyRosy: 0.2,
            beautyGlow: 0.4,
            beautySoften: 0.3,
            beautyDetail: 0.2,
            beautyWarmth: 0.5,
            eyeEnlarge: 0.3,
            faceSlim: 0.2,
            bodySlim: 0.4
        )

        adjustments.resetBeautyAdjustments()

        XCTAssertEqual(adjustments.beautySmooth, 0)
        XCTAssertEqual(adjustments.beautyWrinkle, 0)
        XCTAssertEqual(adjustments.beautyBlemish, 0)
        XCTAssertEqual(adjustments.beautyBrighten, 0)
        XCTAssertEqual(adjustments.beautyWhiten, 0)
        XCTAssertEqual(adjustments.beautyRosy, 0)
        XCTAssertEqual(adjustments.beautyGlow, 0)
        XCTAssertEqual(adjustments.beautySoften, 0)
        XCTAssertEqual(adjustments.beautyDetail, 0)
        XCTAssertEqual(adjustments.beautyWarmth, 0)
        XCTAssertEqual(adjustments.eyeEnlarge, 0)
        XCTAssertEqual(adjustments.faceSlim, 0)
        XCTAssertEqual(adjustments.bodySlim, 0)
        XCTAssertEqual(adjustments.exposure, 0.4)
    }

    func testResetColorMixerClearsMixerButKeepsToneEdits() {
        var mixer = ColorMixerAdjustments()
        mixer.blue = -0.5
        mixer.orange = 0.3
        var adjustments = PhotoAdjustments(saturation: 1.2, colorMixer: mixer)

        adjustments.resetColorMixer()

        XCTAssertFalse(adjustments.colorMixer.hasAdjustments)
        XCTAssertEqual(adjustments.colorMixer, ColorMixerAdjustments())
        XCTAssertEqual(adjustments.saturation, 1.2)
    }

    func testLibrarySortMetadata() {
        XCTAssertEqual(LibrarySort.allCases.map(\.rawValue), ["File Name", "Capture Date", "Rating", "Flag", "Color Label", "Import Date"])
    }

    func testLibraryFilterMetadata() {
        XCTAssertEqual(LibraryFilter.allCases.map(\.rawValue), ["All", "Picked", "Rejected", "Rated", "Unrated", "Unflagged", "Labeled", "Unlabeled", "Red Label", "Yellow Label", "Green Label", "Blue Label", "Purple Label", "Recent", "RAW", "Non-RAW", "Edited", "Unedited"])
    }

    func testPhotoColorLabelMetadata() {
        XCTAssertEqual(PhotoColorLabel.allCases.map(\.rawValue), ["None", "Red", "Yellow", "Green", "Blue", "Purple"])
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
        XCTAssertEqual(ExportFormat.tiff.fileExtension, "tiff")
        XCTAssertEqual(ExportFormat.tiff.typeIdentifier, "public.tiff")
    }
}
