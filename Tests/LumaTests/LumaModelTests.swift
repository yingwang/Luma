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
        XCTAssertEqual(adjustments.perspectiveVertical, 0)
        XCTAssertEqual(adjustments.perspectiveHorizontal, 0)
        XCTAssertEqual(adjustments.cropCenterX, 0.5)
        XCTAssertEqual(adjustments.cropCenterY, 0.5)
        XCTAssertEqual(adjustments.colorMixer, ColorMixerAdjustments())
        XCTAssertEqual(adjustments.fade, 0)
        XCTAssertEqual(adjustments.texture, 0)
        XCTAssertEqual(adjustments.vignetteRadius, 0.5)
        XCTAssertEqual(adjustments.grainAmount, 0)
        XCTAssertEqual(adjustments.grainSize, 0.35)
        XCTAssertEqual(adjustments.grainRoughness, 0.5)
        XCTAssertEqual(adjustments.colorGradeShadowsHue, 220)
        XCTAssertEqual(adjustments.colorGradeShadowsSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeMidtonesHue, 40)
        XCTAssertEqual(adjustments.colorGradeMidtonesSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeHighlightsHue, 45)
        XCTAssertEqual(adjustments.colorGradeHighlightsSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeBalance, 0)
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
        XCTAssertEqual(adjustments.lensDistortionCorrection, 0)
        XCTAssertEqual(adjustments.chromaticAberrationReduction, 0)
        XCTAssertEqual(adjustments.lensVignetteCorrection, 0)
        XCTAssertEqual(adjustments.toneCurveShadows, 0)
        XCTAssertEqual(adjustments.toneCurveDarks, 0)
        XCTAssertEqual(adjustments.toneCurveLights, 0)
        XCTAssertEqual(adjustments.toneCurveHighlights, 0)
        XCTAssertEqual(adjustments.spotHealAmount, 0)
        XCTAssertEqual(adjustments.spotHealX, 0.5)
        XCTAssertEqual(adjustments.spotHealY, 0.5)
        XCTAssertEqual(adjustments.spotHealRadius, 0.06)
        XCTAssertEqual(adjustments.spotHealFeather, 0.04)
        XCTAssertEqual(adjustments.spotHealSourceOffsetX, 0.08)
        XCTAssertEqual(adjustments.spotHealSourceOffsetY, 0)
        XCTAssertTrue(adjustments.spotHealPoints.isEmpty)
    }

    func testLegacySpotHealFieldsBecomeEditableSpotPoint() throws {
        let data = """
        {
          "spotHealAmount": 0.7,
          "spotHealX": 0.25,
          "spotHealY": 0.75,
          "spotHealRadius": 0.08,
          "spotHealFeather": 0.03,
          "spotHealSourceOffsetX": -0.12,
          "spotHealSourceOffsetY": 0.06
        }
        """.data(using: .utf8)!

        let adjustments = try JSONDecoder().decode(PhotoAdjustments.self, from: data)
        let point = try XCTUnwrap(adjustments.effectiveSpotHealPoints.first)

        XCTAssertEqual(adjustments.effectiveSpotHealPoints.count, 1)
        XCTAssertEqual(point.amount, 0.7)
        XCTAssertEqual(point.x, 0.25)
        XCTAssertEqual(point.y, 0.75)
        XCTAssertEqual(point.radius, 0.08)
        XCTAssertEqual(point.feather, 0.03)
        XCTAssertEqual(point.sourceOffsetX, -0.12)
        XCTAssertEqual(point.sourceOffsetY, 0.06)
    }

    func testSpotHealPointsRoundTrip() throws {
        let point = SpotHealPoint(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            amount: 0.6,
            x: 0.2,
            y: 0.4,
            radius: 0.05,
            feather: 0.02,
            sourceOffsetX: 0.1,
            sourceOffsetY: -0.1
        )
        let original = PhotoAdjustments(spotHealPoints: [point])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhotoAdjustments.self, from: data)

        XCTAssertEqual(decoded.spotHealPoints, [point])
        XCTAssertEqual(decoded.effectiveSpotHealPoints, [point])
    }

    func testCropAspectRatios() {
        XCTAssertNil(CropAspect.original.ratio)
        XCTAssertEqual(CropAspect.square.ratio, 1)
        XCTAssertEqual(CropAspect.twoByThree.ratio, 2.0 / 3.0)
        XCTAssertEqual(CropAspect.portrait.ratio, 0.8)
        XCTAssertEqual(CropAspect.threeByFour.ratio, 0.75)
        XCTAssertEqual(CropAspect.classic.ratio, 1.5)
        XCTAssertEqual(CropAspect.fourByThree.ratio, 4.0 / 3.0)
        XCTAssertEqual(CropAspect.fiveByFour.ratio, 1.25)
        XCTAssertEqual(CropAspect.wide.ratio, 16.0 / 9.0)
    }

    func testColorMixerDetectsAdjustments() {
        XCTAssertFalse(ColorMixerAdjustments().hasAdjustments)

        var mixer = ColorMixerAdjustments()
        mixer.blue = -0.35

        XCTAssertTrue(mixer.hasAdjustments)

        mixer = ColorMixerAdjustments()
        mixer.orangeLuminance = 0.25

        XCTAssertTrue(mixer.hasAdjustments)

        mixer = ColorMixerAdjustments()
        mixer.greenHue = -0.2

        XCTAssertTrue(mixer.hasAdjustments)
    }

    func testColorMixerDecodesLegacySaturationFields() throws {
        let data = """
        {
          "orange": 0.2,
          "blue": -0.35
        }
        """.data(using: .utf8)!

        let mixer = try JSONDecoder().decode(ColorMixerAdjustments.self, from: data)

        XCTAssertEqual(mixer.orange, 0.2)
        XCTAssertEqual(mixer.blue, -0.35)
        XCTAssertEqual(mixer.orangeHue, 0)
        XCTAssertEqual(mixer.blueHue, 0)
        XCTAssertEqual(mixer.orangeLuminance, 0)
        XCTAssertEqual(mixer.blueLuminance, 0)
    }

    func testLinearGradientDirectionCanBeInverted() {
        var adjustments = PhotoAdjustments(linearStartY: 0.9, linearEndY: 0.25)

        adjustments.invertLinearGradientDirection()

        XCTAssertEqual(adjustments.linearStartY, 0.25)
        XCTAssertEqual(adjustments.linearEndY, 0.9)
    }

    func testLensCorrectionsCanBeResetWithoutChangingToneAdjustments() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            lensDistortionCorrection: -0.4,
            chromaticAberrationReduction: 0.8,
            lensVignetteCorrection: 0.7
        )

        adjustments.resetLensCorrections()

        XCTAssertEqual(adjustments.exposure, 0.6)
        XCTAssertEqual(adjustments.lensDistortionCorrection, 0)
        XCTAssertEqual(adjustments.chromaticAberrationReduction, 0)
        XCTAssertEqual(adjustments.lensVignetteCorrection, 0)
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
            perspectiveVertical: 0.4,
            perspectiveHorizontal: -0.3,
            rotationTurns: 1,
            cropAspect: .square,
            cropCenterX: 0.12,
            cropCenterY: 0.88,
            flipHorizontal: true,
            flipVertical: true
        )

        adjustments.resetCropTransform()

        XCTAssertEqual(adjustments.exposure, 0.6)
        XCTAssertEqual(adjustments.straighten, 0)
        XCTAssertEqual(adjustments.perspectiveVertical, 0)
        XCTAssertEqual(adjustments.perspectiveHorizontal, 0)
        XCTAssertEqual(adjustments.rotationTurns, 0)
        XCTAssertEqual(adjustments.cropAspect, .original)
        XCTAssertEqual(adjustments.cropCenterX, 0.5)
        XCTAssertEqual(adjustments.cropCenterY, 0.5)
        XCTAssertFalse(adjustments.flipHorizontal)
        XCTAssertFalse(adjustments.flipVertical)
    }

    func testToneAdjustmentsCanBeResetWithoutChangingCropOrLocalAdjustments() {
        var adjustments = PhotoAdjustments(
            exposure: 0.6,
            contrast: 1.4,
            saturation: 0.7,
            warmth: 250,
            fade: 0.42,
            texture: 0.35,
            vignetteRadius: 0.18,
            grainAmount: 0.5,
            grainSize: 0.8,
            grainRoughness: 0.2,
            toneCurveShadows: 0.2,
            toneCurveDarks: -0.1,
            toneCurveLights: 0.12,
            toneCurveHighlights: -0.18,
            colorGradeShadowsHue: 210,
            colorGradeShadowsSaturation: 0.4,
            colorGradeMidtonesHue: 75,
            colorGradeMidtonesSaturation: 0.2,
            colorGradeHighlightsHue: 38,
            colorGradeHighlightsSaturation: 0.35,
            colorGradeBalance: -0.45,
            radialExposure: -0.5,
            lensDistortionCorrection: -0.35,
            chromaticAberrationReduction: 0.55,
            lensVignetteCorrection: 0.45,
            straighten: 12,
            perspectiveVertical: 0.25,
            perspectiveHorizontal: -0.15,
            cropAspect: .square,
            cropCenterX: 0.22,
            cropCenterY: 0.78,
            flipHorizontal: true
        )

        adjustments.resetToneAdjustments()

        XCTAssertEqual(adjustments.exposure, 0)
        XCTAssertEqual(adjustments.contrast, 1)
        XCTAssertEqual(adjustments.saturation, 1)
        XCTAssertEqual(adjustments.warmth, 0)
        XCTAssertEqual(adjustments.fade, 0)
        XCTAssertEqual(adjustments.texture, 0)
        XCTAssertEqual(adjustments.vignetteRadius, 0.5)
        XCTAssertEqual(adjustments.grainAmount, 0)
        XCTAssertEqual(adjustments.grainSize, 0.35)
        XCTAssertEqual(adjustments.grainRoughness, 0.5)
        XCTAssertEqual(adjustments.toneCurveShadows, 0)
        XCTAssertEqual(adjustments.toneCurveDarks, 0)
        XCTAssertEqual(adjustments.toneCurveLights, 0)
        XCTAssertEqual(adjustments.toneCurveHighlights, 0)
        XCTAssertEqual(adjustments.colorGradeShadowsHue, 220)
        XCTAssertEqual(adjustments.colorGradeShadowsSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeMidtonesHue, 40)
        XCTAssertEqual(adjustments.colorGradeMidtonesSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeHighlightsHue, 45)
        XCTAssertEqual(adjustments.colorGradeHighlightsSaturation, 0)
        XCTAssertEqual(adjustments.colorGradeBalance, 0)
        XCTAssertEqual(adjustments.radialExposure, -0.5)
        XCTAssertEqual(adjustments.lensDistortionCorrection, -0.35)
        XCTAssertEqual(adjustments.chromaticAberrationReduction, 0.55)
        XCTAssertEqual(adjustments.lensVignetteCorrection, 0.45)
        XCTAssertEqual(adjustments.straighten, 12)
        XCTAssertEqual(adjustments.perspectiveVertical, 0.25)
        XCTAssertEqual(adjustments.perspectiveHorizontal, -0.15)
        XCTAssertEqual(adjustments.cropAspect, .square)
        XCTAssertEqual(adjustments.cropCenterX, 0.22)
        XCTAssertEqual(adjustments.cropCenterY, 0.78)
        XCTAssertTrue(adjustments.flipHorizontal)
    }

    func testLibrarySortMetadata() {
        XCTAssertEqual(LibrarySort.allCases.map(\.rawValue), ["File Name", "Capture Date", "Rating", "Flag", "Color Label", "File Size", "Format", "Camera", "Lens", "Import Date"])
    }

    func testLibrarySortOrderMetadata() {
        XCTAssertEqual(LibrarySortOrder.allCases.map(\.rawValue), ["Standard", "Reverse"])
    }

    func testLibraryFilterMetadata() {
        XCTAssertEqual(LibraryFilter.allCases.map(\.rawValue), ["All", "Picked", "Rejected", "Rated", "Unrated", "Unflagged", "Labeled", "Unlabeled", "Red Label", "Yellow Label", "Green Label", "Blue Label", "Purple Label", "Recent", "RAW", "Non-RAW", "Edited", "Unedited"])
    }

    func testPhotoColorLabelMetadata() {
        XCTAssertEqual(PhotoColorLabel.allCases.map(\.rawValue), ["None", "Red", "Yellow", "Green", "Blue", "Purple"])
    }

    func testPhotoSearchMatchesFileNameAndMetadata() {
        let metadata = PhotoMetadata(
            pixelWidth: 6000,
            pixelHeight: 4000,
            fileSize: 42_000_000,
            formatName: "DNG",
            isRaw: true,
            cameraMake: "Sony",
            cameraModel: "A7C II",
            lensModel: "FE 35mm F1.8",
            iso: 400,
            aperture: 2.8,
            shutterSpeed: 1 / 250,
            focalLength: 35,
            captureDate: nil
        )
        let asset = PhotoAsset(
            url: URL(fileURLWithPath: "/tmp/stockholm-street.dng"),
            metadata: metadata,
            histogramBins: nil
        )

        XCTAssertTrue(asset.matchesSearch("stockholm"))
        XCTAssertTrue(asset.matchesSearch("sony 35"))
        XCTAssertTrue(asset.matchesSearch("raw"))
        XCTAssertTrue(asset.matchesSearch("iso 400"))
        XCTAssertFalse(asset.matchesSearch("canon"))
    }

    func testPhotoPresetMetadataAndRepresentativeAdjustments() {
        XCTAssertEqual(PhotoPreset.allCases.map(\.rawValue), ["Neutral", "Vivid", "Landscape", "Soft Portrait", "Clean Portrait", "Black & White", "High Contrast B&W", "Warm Film", "Matte Film"])
        XCTAssertEqual(PhotoPreset.landscape.adjustments.dehaze, 0.22)
        XCTAssertEqual(PhotoPreset.cleanPortrait.adjustments.beautySmooth, 0.18)
        XCTAssertEqual(PhotoPreset.highContrastBlackAndWhite.adjustments.saturation, 0)
        XCTAssertEqual(PhotoPreset.matteFilm.adjustments.grainAmount, 0.16)
    }

    func testExportPresetSettings() {
        XCTAssertEqual(ExportPreset.fullSize.jpegQuality, 0.95)
        XCTAssertEqual(ExportPreset.fullSize.longEdge, 0)
        XCTAssertEqual(ExportPreset.fullSize.outputSharpening, 0.15)
        XCTAssertEqual(ExportPreset.largeWeb.longEdge, 2560)
        XCTAssertEqual(ExportPreset.largeWeb.outputSharpening, 0.35)
        XCTAssertEqual(ExportPreset.social.longEdge, 1600)
        XCTAssertEqual(ExportPreset.social.outputSharpening, 0.45)
        XCTAssertEqual(ExportPreset.thumbnail.longEdge, 800)
        XCTAssertEqual(ExportPreset.thumbnail.outputSharpening, 0.55)
    }

    func testExportFormatMetadata() {
        XCTAssertEqual(ExportFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ExportFormat.jpeg.typeIdentifier, "public.jpeg")
        XCTAssertEqual(ExportFormat.heic.fileExtension, "heic")
        XCTAssertEqual(ExportFormat.heic.typeIdentifier, "public.heic")
        XCTAssertEqual(ExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportFormat.png.typeIdentifier, "public.png")
        XCTAssertEqual(ExportFormat.tiff.fileExtension, "tiff")
        XCTAssertEqual(ExportFormat.tiff.typeIdentifier, "public.tiff")
    }
}
