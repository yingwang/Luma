import AppKit
import Foundation

struct PhotoAsset: Identifiable, Equatable {
    let id: UUID
    let url: URL
    var metadata: PhotoMetadata?
    var histogramBins: [Double]?
    var rgbHistogramBins: RGBHistogram?
    var thumbnail: NSImage?
    var adjustments = PhotoAdjustments()
    var rating: Int = 0
    var flag: PhotoFlag = .none
    var colorLabel: PhotoColorLabel = .none
    var importedAt: Date = .distantPast

    var fileName: String {
        url.lastPathComponent
    }

    func matchesSearch(_ query: String) -> Bool {
        let terms = query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !terms.isEmpty else {
            return true
        }

        let searchableText = [
            fileName,
            metadata?.formatText,
            metadata?.cameraMake,
            metadata?.cameraModel,
            metadata?.cameraText,
            metadata?.lensModel,
            metadata?.exposureText,
            metadata?.focalLengthText
        ]
        .compactMap { $0 }

        return terms.allSatisfy { term in
            searchableText.contains {
                $0.localizedCaseInsensitiveContains(term)
            }
        }
    }

    init(
        id: UUID = UUID(),
        url: URL,
        metadata: PhotoMetadata?,
        histogramBins: [Double]?,
        rgbHistogramBins: RGBHistogram? = nil,
        thumbnail: NSImage? = nil,
        adjustments: PhotoAdjustments = .neutral,
        rating: Int = 0,
        flag: PhotoFlag = .none,
        colorLabel: PhotoColorLabel = .none,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.metadata = metadata
        self.histogramBins = histogramBins
        self.rgbHistogramBins = rgbHistogramBins
        self.thumbnail = thumbnail
        self.adjustments = adjustments
        self.rating = rating
        self.flag = flag
        self.colorLabel = colorLabel
        self.importedAt = importedAt
    }
}

struct RGBHistogram: Equatable {
    let red: [Double]
    let green: [Double]
    let blue: [Double]
}

enum PhotoFlag: String, CaseIterable, Codable, Equatable {
    case none = "None"
    case picked = "Picked"
    case rejected = "Rejected"
}

enum PhotoColorLabel: String, CaseIterable, Codable, Identifiable, Equatable {
    case none = "None"
    case red = "Red"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"

    var id: String {
        rawValue
    }
}

enum LibraryFilter: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case picked = "Picked"
    case rejected = "Rejected"
    case rated = "Rated"
    case unrated = "Unrated"
    case unflagged = "Unflagged"
    case labeled = "Labeled"
    case unlabeled = "Unlabeled"
    case redLabel = "Red Label"
    case yellowLabel = "Yellow Label"
    case greenLabel = "Green Label"
    case blueLabel = "Blue Label"
    case purpleLabel = "Purple Label"
    case recent = "Recent"
    case raw = "RAW"
    case nonRaw = "Non-RAW"
    case edited = "Edited"
    case unedited = "Unedited"

    var id: String {
        rawValue
    }
}

enum LibrarySort: String, CaseIterable, Codable, Identifiable {
    case fileName = "File Name"
    case captureDate = "Capture Date"
    case rating = "Rating"
    case flag = "Flag"
    case colorLabel = "Color Label"
    case fileSize = "File Size"
    case format = "Format"
    case camera = "Camera"
    case lens = "Lens"
    case importDate = "Import Date"

    var id: String {
        rawValue
    }
}

enum LibrarySortOrder: String, CaseIterable, Codable, Identifiable {
    case standard = "Standard"
    case reverse = "Reverse"

    var id: String {
        rawValue
    }
}

enum PhotoPreset: String, CaseIterable, Identifiable {
    case neutral = "Neutral"
    case vivid = "Vivid"
    case landscape = "Landscape"
    case softPortrait = "Soft Portrait"
    case cleanPortrait = "Clean Portrait"
    case blackAndWhite = "Black & White"
    case highContrastBlackAndWhite = "High Contrast B&W"
    case warmFilm = "Warm Film"
    case matteFilm = "Matte Film"

    var id: String {
        rawValue
    }

    var adjustments: PhotoAdjustments {
        switch self {
        case .neutral:
            return .neutral
        case .vivid:
            return PhotoAdjustments(exposure: 0.1, contrast: 1.18, saturation: 1.12, warmth: 80, vibrance: 0.35, sharpness: 0.7)
        case .landscape:
            return PhotoAdjustments(exposure: 0.05, highlights: -0.18, shadows: 0.12, whites: 0.08, blacks: -0.08, contrast: 1.14, saturation: 1.04, vibrance: 0.28, clarity: 0.35, dehaze: 0.22, sharpness: 0.65)
        case .softPortrait:
            return PhotoAdjustments(exposure: 0.2, contrast: 0.92, saturation: 0.96, warmth: 180, vibrance: 0.08, sharpness: 0.25)
        case .cleanPortrait:
            return PhotoAdjustments(exposure: 0.16, highlights: -0.08, shadows: 0.10, contrast: 0.96, saturation: 0.98, warmth: 140, vibrance: 0.10, texture: -0.12, sharpness: 0.28, beautySmooth: 0.18, beautyBrighten: 0.12, beautyWhiten: 0.10)
        case .blackAndWhite:
            return PhotoAdjustments(exposure: 0, contrast: 1.25, saturation: 0, warmth: 0, vibrance: 0, sharpness: 0.45)
        case .highContrastBlackAndWhite:
            return PhotoAdjustments(exposure: 0, highlights: -0.08, shadows: 0.05, whites: 0.16, blacks: -0.18, contrast: 1.45, saturation: 0, vibrance: 0, clarity: 0.45, dehaze: 0.18, sharpness: 0.65)
        case .warmFilm:
            return PhotoAdjustments(exposure: 0.05, contrast: 1.08, saturation: 0.94, warmth: 420, vibrance: 0.18, sharpness: 0.35)
        case .matteFilm:
            return PhotoAdjustments(exposure: 0.04, highlights: -0.10, shadows: 0.18, blacks: 0.22, contrast: 0.94, saturation: 0.92, warmth: 260, vibrance: 0.08, sharpness: 0.24, grainAmount: 0.16, grainSize: 0.42, grainRoughness: 0.55, toneCurveShadows: 0.22, toneCurveHighlights: -0.10)
        }
    }
}

enum ExportPreset: String, CaseIterable, Identifiable {
    case fullSize = "Full Size"
    case largeWeb = "Large Web"
    case social = "Social"
    case thumbnail = "Thumbnail"

    var id: String {
        rawValue
    }

    var jpegQuality: Double {
        switch self {
        case .fullSize:
            0.95
        case .largeWeb:
            0.88
        case .social:
            0.86
        case .thumbnail:
            0.82
        }
    }

    var longEdge: Double {
        switch self {
        case .fullSize:
            0
        case .largeWeb:
            2560
        case .social:
            1600
        case .thumbnail:
            800
        }
    }

    var outputSharpening: Double {
        switch self {
        case .fullSize:
            0.15
        case .largeWeb:
            0.35
        case .social:
            0.45
        case .thumbnail:
            0.55
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case heic = "HEIC"
    case png = "PNG"
    case tiff = "TIFF"

    var id: String {
        rawValue
    }

    var fileExtension: String {
        switch self {
        case .jpeg:
            "jpg"
        case .heic:
            "heic"
        case .png:
            "png"
        case .tiff:
            "tiff"
        }
    }

    var typeIdentifier: String {
        switch self {
        case .jpeg:
            "public.jpeg"
        case .heic:
            "public.heic"
        case .png:
            "public.png"
        case .tiff:
            "public.tiff"
        }
    }
}

struct SpotHealPoint: Codable, Equatable, Identifiable {
    let id: UUID
    var amount: Double
    var x: Double
    var y: Double
    var radius: Double
    var feather: Double
    var sourceOffsetX: Double
    var sourceOffsetY: Double

    init(
        id: UUID = UUID(),
        amount: Double = 0.85,
        x: Double = 0.5,
        y: Double = 0.5,
        radius: Double = 0.04,
        feather: Double = 0.035,
        sourceOffsetX: Double = 0.08,
        sourceOffsetY: Double = 0
    ) {
        self.id = id
        self.amount = amount
        self.x = x
        self.y = y
        self.radius = radius
        self.feather = feather
        self.sourceOffsetX = sourceOffsetX
        self.sourceOffsetY = sourceOffsetY
    }
}

struct PhotoAdjustments: Codable, Equatable {
    var exposure: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var hue: Double = 0
    var warmth: Double = 0
    var tint: Double = 0
    var vibrance: Double = 0
    var fade: Double = 0
    var texture: Double = 0
    var clarity: Double = 0
    var dehaze: Double = 0
    var noiseReduction: Double = 0
    var sharpness: Double = 0
    var vignette: Double = 0
    var vignetteRadius: Double = 0.5
    var grainAmount: Double = 0
    var grainSize: Double = 0.35
    var grainRoughness: Double = 0.5
    var toneCurveShadows: Double = 0
    var toneCurveDarks: Double = 0
    var toneCurveLights: Double = 0
    var toneCurveHighlights: Double = 0
    var colorGradeShadowsHue: Double = 220
    var colorGradeShadowsSaturation: Double = 0
    var colorGradeMidtonesHue: Double = 40
    var colorGradeMidtonesSaturation: Double = 0
    var colorGradeHighlightsHue: Double = 45
    var colorGradeHighlightsSaturation: Double = 0
    var beautySmooth: Double = 0
    var beautyWrinkle: Double = 0
    var beautyBlemish: Double = 0
    var beautyBrighten: Double = 0
    var beautyWhiten: Double = 0
    var beautyRosy: Double = 0
    var beautyGlow: Double = 0
    var beautySoften: Double = 0
    var beautyDetail: Double = 0
    var beautyWarmth: Double = 0
    var eyeEnlarge: Double = 0
    var faceSlim: Double = 0
    var bodySlim: Double = 0
    var radialExposure: Double = 0
    var radialCenterX: Double = 0.5
    var radialCenterY: Double = 0.5
    var radialRadius: Double = 0.35
    var radialFeather: Double = 0.25
    var radialInvert: Bool = false
    var linearExposure: Double = 0
    var linearStartY: Double = 1
    var linearEndY: Double = 0.65
    var linearInvert: Bool = false
    var lensDistortionCorrection: Double = 0
    var chromaticAberrationReduction: Double = 0
    var lensVignetteCorrection: Double = 0
    var spotHealAmount: Double = 0
    var spotHealX: Double = 0.5
    var spotHealY: Double = 0.5
    var spotHealRadius: Double = 0.06
    var spotHealFeather: Double = 0.04
    var spotHealSourceOffsetX: Double = 0.08
    var spotHealSourceOffsetY: Double = 0
    var spotHealPoints: [SpotHealPoint] = []
    var straighten: Double = 0
    var perspectiveVertical: Double = 0
    var perspectiveHorizontal: Double = 0
    var rotationTurns: Int = 0
    var cropAspect: CropAspect = .original
    var cropCenterX: Double = 0.5
    var cropCenterY: Double = 0.5
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false
    var colorMixer = ColorMixerAdjustments()

    static let neutral = PhotoAdjustments()

    private enum CodingKeys: String, CodingKey {
        case exposure
        case highlights
        case shadows
        case whites
        case blacks
        case contrast
        case saturation
        case hue
        case warmth
        case tint
        case vibrance
        case fade
        case texture
        case clarity
        case dehaze
        case noiseReduction
        case sharpness
        case vignette
        case vignetteRadius
        case grainAmount
        case grainSize
        case grainRoughness
        case toneCurveShadows
        case toneCurveDarks
        case toneCurveLights
        case toneCurveHighlights
        case colorGradeShadowsHue
        case colorGradeShadowsSaturation
        case colorGradeMidtonesHue
        case colorGradeMidtonesSaturation
        case colorGradeHighlightsHue
        case colorGradeHighlightsSaturation
        case beautySmooth
        case beautyWrinkle
        case beautyBlemish
        case beautyBrighten
        case beautyWhiten
        case beautyRosy
        case beautyGlow
        case beautySoften
        case beautyDetail
        case beautyWarmth
        case eyeEnlarge
        case faceSlim
        case bodySlim
        case radialExposure
        case radialCenterX
        case radialCenterY
        case radialRadius
        case radialFeather
        case radialInvert
        case linearExposure
        case linearStartY
        case linearEndY
        case linearInvert
        case lensDistortionCorrection
        case chromaticAberrationReduction
        case lensVignetteCorrection
        case spotHealAmount
        case spotHealX
        case spotHealY
        case spotHealRadius
        case spotHealFeather
        case spotHealSourceOffsetX
        case spotHealSourceOffsetY
        case spotHealPoints
        case straighten
        case perspectiveVertical
        case perspectiveHorizontal
        case rotationTurns
        case cropAspect
        case cropCenterX
        case cropCenterY
        case flipHorizontal
        case flipVertical
        case colorMixer
    }

    init(
        exposure: Double = 0,
        highlights: Double = 0,
        shadows: Double = 0,
        whites: Double = 0,
        blacks: Double = 0,
        contrast: Double = 1,
        saturation: Double = 1,
        hue: Double = 0,
        warmth: Double = 0,
        tint: Double = 0,
        vibrance: Double = 0,
        fade: Double = 0,
        texture: Double = 0,
        clarity: Double = 0,
        dehaze: Double = 0,
        noiseReduction: Double = 0,
        sharpness: Double = 0,
        vignette: Double = 0,
        vignetteRadius: Double = 0.5,
        grainAmount: Double = 0,
        grainSize: Double = 0.35,
        grainRoughness: Double = 0.5,
        toneCurveShadows: Double = 0,
        toneCurveDarks: Double = 0,
        toneCurveLights: Double = 0,
        toneCurveHighlights: Double = 0,
        colorGradeShadowsHue: Double = 220,
        colorGradeShadowsSaturation: Double = 0,
        colorGradeMidtonesHue: Double = 40,
        colorGradeMidtonesSaturation: Double = 0,
        colorGradeHighlightsHue: Double = 45,
        colorGradeHighlightsSaturation: Double = 0,
        beautySmooth: Double = 0,
        beautyWrinkle: Double = 0,
        beautyBlemish: Double = 0,
        beautyBrighten: Double = 0,
        beautyWhiten: Double = 0,
        beautyRosy: Double = 0,
        beautyGlow: Double = 0,
        beautySoften: Double = 0,
        beautyDetail: Double = 0,
        beautyWarmth: Double = 0,
        eyeEnlarge: Double = 0,
        faceSlim: Double = 0,
        bodySlim: Double = 0,
        radialExposure: Double = 0,
        radialCenterX: Double = 0.5,
        radialCenterY: Double = 0.5,
        radialRadius: Double = 0.35,
        radialFeather: Double = 0.25,
        radialInvert: Bool = false,
        linearExposure: Double = 0,
        linearStartY: Double = 1,
        linearEndY: Double = 0.65,
        linearInvert: Bool = false,
        lensDistortionCorrection: Double = 0,
        chromaticAberrationReduction: Double = 0,
        lensVignetteCorrection: Double = 0,
        spotHealAmount: Double = 0,
        spotHealX: Double = 0.5,
        spotHealY: Double = 0.5,
        spotHealRadius: Double = 0.06,
        spotHealFeather: Double = 0.04,
        spotHealSourceOffsetX: Double = 0.08,
        spotHealSourceOffsetY: Double = 0,
        spotHealPoints: [SpotHealPoint] = [],
        straighten: Double = 0,
        perspectiveVertical: Double = 0,
        perspectiveHorizontal: Double = 0,
        rotationTurns: Int = 0,
        cropAspect: CropAspect = .original,
        cropCenterX: Double = 0.5,
        cropCenterY: Double = 0.5,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        colorMixer: ColorMixerAdjustments = ColorMixerAdjustments()
    ) {
        self.exposure = exposure
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
        self.contrast = contrast
        self.saturation = saturation
        self.hue = hue
        self.warmth = warmth
        self.tint = tint
        self.vibrance = vibrance
        self.fade = fade
        self.texture = texture
        self.clarity = clarity
        self.dehaze = dehaze
        self.noiseReduction = noiseReduction
        self.sharpness = sharpness
        self.vignette = vignette
        self.vignetteRadius = vignetteRadius
        self.grainAmount = grainAmount
        self.grainSize = grainSize
        self.grainRoughness = grainRoughness
        self.toneCurveShadows = toneCurveShadows
        self.toneCurveDarks = toneCurveDarks
        self.toneCurveLights = toneCurveLights
        self.toneCurveHighlights = toneCurveHighlights
        self.colorGradeShadowsHue = colorGradeShadowsHue
        self.colorGradeShadowsSaturation = colorGradeShadowsSaturation
        self.colorGradeMidtonesHue = colorGradeMidtonesHue
        self.colorGradeMidtonesSaturation = colorGradeMidtonesSaturation
        self.colorGradeHighlightsHue = colorGradeHighlightsHue
        self.colorGradeHighlightsSaturation = colorGradeHighlightsSaturation
        self.beautySmooth = beautySmooth
        self.beautyWrinkle = beautyWrinkle
        self.beautyBlemish = beautyBlemish
        self.beautyBrighten = beautyBrighten
        self.beautyWhiten = beautyWhiten
        self.beautyRosy = beautyRosy
        self.beautyGlow = beautyGlow
        self.beautySoften = beautySoften
        self.beautyDetail = beautyDetail
        self.beautyWarmth = beautyWarmth
        self.eyeEnlarge = eyeEnlarge
        self.faceSlim = faceSlim
        self.bodySlim = bodySlim
        self.radialExposure = radialExposure
        self.radialCenterX = radialCenterX
        self.radialCenterY = radialCenterY
        self.radialRadius = radialRadius
        self.radialFeather = radialFeather
        self.radialInvert = radialInvert
        self.linearExposure = linearExposure
        self.linearStartY = linearStartY
        self.linearEndY = linearEndY
        self.linearInvert = linearInvert
        self.lensDistortionCorrection = lensDistortionCorrection
        self.chromaticAberrationReduction = chromaticAberrationReduction
        self.lensVignetteCorrection = lensVignetteCorrection
        self.spotHealAmount = spotHealAmount
        self.spotHealX = spotHealX
        self.spotHealY = spotHealY
        self.spotHealRadius = spotHealRadius
        self.spotHealFeather = spotHealFeather
        self.spotHealSourceOffsetX = spotHealSourceOffsetX
        self.spotHealSourceOffsetY = spotHealSourceOffsetY
        self.spotHealPoints = Self.normalizedSpotHealPoints(
            points: spotHealPoints,
            legacyAmount: spotHealAmount,
            legacyX: spotHealX,
            legacyY: spotHealY,
            legacyRadius: spotHealRadius,
            legacyFeather: spotHealFeather,
            legacySourceOffsetX: spotHealSourceOffsetX,
            legacySourceOffsetY: spotHealSourceOffsetY
        )
        self.straighten = straighten
        self.perspectiveVertical = perspectiveVertical
        self.perspectiveHorizontal = perspectiveHorizontal
        self.rotationTurns = rotationTurns
        self.cropAspect = cropAspect
        self.cropCenterX = cropCenterX
        self.cropCenterY = cropCenterY
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.colorMixer = colorMixer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        whites = try container.decodeIfPresent(Double.self, forKey: .whites) ?? 0
        blacks = try container.decodeIfPresent(Double.self, forKey: .blacks) ?? 0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        hue = try container.decodeIfPresent(Double.self, forKey: .hue) ?? 0
        warmth = try container.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
        tint = try container.decodeIfPresent(Double.self, forKey: .tint) ?? 0
        vibrance = try container.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
        fade = try container.decodeIfPresent(Double.self, forKey: .fade) ?? 0
        texture = try container.decodeIfPresent(Double.self, forKey: .texture) ?? 0
        clarity = try container.decodeIfPresent(Double.self, forKey: .clarity) ?? 0
        dehaze = try container.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0
        noiseReduction = try container.decodeIfPresent(Double.self, forKey: .noiseReduction) ?? 0
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        vignette = try container.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        vignetteRadius = try container.decodeIfPresent(Double.self, forKey: .vignetteRadius) ?? 0.5
        grainAmount = try container.decodeIfPresent(Double.self, forKey: .grainAmount) ?? 0
        grainSize = try container.decodeIfPresent(Double.self, forKey: .grainSize) ?? 0.35
        grainRoughness = try container.decodeIfPresent(Double.self, forKey: .grainRoughness) ?? 0.5
        toneCurveShadows = try container.decodeIfPresent(Double.self, forKey: .toneCurveShadows) ?? 0
        toneCurveDarks = try container.decodeIfPresent(Double.self, forKey: .toneCurveDarks) ?? 0
        toneCurveLights = try container.decodeIfPresent(Double.self, forKey: .toneCurveLights) ?? 0
        toneCurveHighlights = try container.decodeIfPresent(Double.self, forKey: .toneCurveHighlights) ?? 0
        colorGradeShadowsHue = try container.decodeIfPresent(Double.self, forKey: .colorGradeShadowsHue) ?? 220
        colorGradeShadowsSaturation = try container.decodeIfPresent(Double.self, forKey: .colorGradeShadowsSaturation) ?? 0
        colorGradeMidtonesHue = try container.decodeIfPresent(Double.self, forKey: .colorGradeMidtonesHue) ?? 40
        colorGradeMidtonesSaturation = try container.decodeIfPresent(Double.self, forKey: .colorGradeMidtonesSaturation) ?? 0
        colorGradeHighlightsHue = try container.decodeIfPresent(Double.self, forKey: .colorGradeHighlightsHue) ?? 45
        colorGradeHighlightsSaturation = try container.decodeIfPresent(Double.self, forKey: .colorGradeHighlightsSaturation) ?? 0
        beautySmooth = try container.decodeIfPresent(Double.self, forKey: .beautySmooth) ?? 0
        beautyWrinkle = try container.decodeIfPresent(Double.self, forKey: .beautyWrinkle) ?? 0
        beautyBlemish = try container.decodeIfPresent(Double.self, forKey: .beautyBlemish) ?? 0
        beautyBrighten = try container.decodeIfPresent(Double.self, forKey: .beautyBrighten) ?? 0
        beautyWhiten = try container.decodeIfPresent(Double.self, forKey: .beautyWhiten) ?? 0
        beautyRosy = try container.decodeIfPresent(Double.self, forKey: .beautyRosy) ?? 0
        beautyGlow = try container.decodeIfPresent(Double.self, forKey: .beautyGlow) ?? 0
        beautySoften = try container.decodeIfPresent(Double.self, forKey: .beautySoften) ?? 0
        beautyDetail = try container.decodeIfPresent(Double.self, forKey: .beautyDetail) ?? 0
        beautyWarmth = try container.decodeIfPresent(Double.self, forKey: .beautyWarmth) ?? 0
        eyeEnlarge = try container.decodeIfPresent(Double.self, forKey: .eyeEnlarge) ?? 0
        faceSlim = try container.decodeIfPresent(Double.self, forKey: .faceSlim) ?? 0
        bodySlim = try container.decodeIfPresent(Double.self, forKey: .bodySlim) ?? 0
        radialExposure = try container.decodeIfPresent(Double.self, forKey: .radialExposure) ?? 0
        radialCenterX = try container.decodeIfPresent(Double.self, forKey: .radialCenterX) ?? 0.5
        radialCenterY = try container.decodeIfPresent(Double.self, forKey: .radialCenterY) ?? 0.5
        radialRadius = try container.decodeIfPresent(Double.self, forKey: .radialRadius) ?? 0.35
        radialFeather = try container.decodeIfPresent(Double.self, forKey: .radialFeather) ?? 0.25
        radialInvert = try container.decodeIfPresent(Bool.self, forKey: .radialInvert) ?? false
        linearExposure = try container.decodeIfPresent(Double.self, forKey: .linearExposure) ?? 0
        linearStartY = try container.decodeIfPresent(Double.self, forKey: .linearStartY) ?? 1
        linearEndY = try container.decodeIfPresent(Double.self, forKey: .linearEndY) ?? 0.65
        linearInvert = try container.decodeIfPresent(Bool.self, forKey: .linearInvert) ?? false
        lensDistortionCorrection = try container.decodeIfPresent(Double.self, forKey: .lensDistortionCorrection) ?? 0
        chromaticAberrationReduction = try container.decodeIfPresent(Double.self, forKey: .chromaticAberrationReduction) ?? 0
        lensVignetteCorrection = try container.decodeIfPresent(Double.self, forKey: .lensVignetteCorrection) ?? 0
        spotHealAmount = try container.decodeIfPresent(Double.self, forKey: .spotHealAmount) ?? 0
        spotHealX = try container.decodeIfPresent(Double.self, forKey: .spotHealX) ?? 0.5
        spotHealY = try container.decodeIfPresent(Double.self, forKey: .spotHealY) ?? 0.5
        spotHealRadius = try container.decodeIfPresent(Double.self, forKey: .spotHealRadius) ?? 0.06
        spotHealFeather = try container.decodeIfPresent(Double.self, forKey: .spotHealFeather) ?? 0.04
        spotHealSourceOffsetX = try container.decodeIfPresent(Double.self, forKey: .spotHealSourceOffsetX) ?? 0.08
        spotHealSourceOffsetY = try container.decodeIfPresent(Double.self, forKey: .spotHealSourceOffsetY) ?? 0
        let decodedSpotHealPoints = try container.decodeIfPresent([SpotHealPoint].self, forKey: .spotHealPoints) ?? []
        spotHealPoints = Self.normalizedSpotHealPoints(
            points: decodedSpotHealPoints,
            legacyAmount: spotHealAmount,
            legacyX: spotHealX,
            legacyY: spotHealY,
            legacyRadius: spotHealRadius,
            legacyFeather: spotHealFeather,
            legacySourceOffsetX: spotHealSourceOffsetX,
            legacySourceOffsetY: spotHealSourceOffsetY
        )
        straighten = try container.decodeIfPresent(Double.self, forKey: .straighten) ?? 0
        perspectiveVertical = try container.decodeIfPresent(Double.self, forKey: .perspectiveVertical) ?? 0
        perspectiveHorizontal = try container.decodeIfPresent(Double.self, forKey: .perspectiveHorizontal) ?? 0
        rotationTurns = try container.decodeIfPresent(Int.self, forKey: .rotationTurns) ?? 0
        cropAspect = try container.decodeIfPresent(CropAspect.self, forKey: .cropAspect) ?? .original
        cropCenterX = try container.decodeIfPresent(Double.self, forKey: .cropCenterX) ?? 0.5
        cropCenterY = try container.decodeIfPresent(Double.self, forKey: .cropCenterY) ?? 0.5
        flipHorizontal = try container.decodeIfPresent(Bool.self, forKey: .flipHorizontal) ?? false
        flipVertical = try container.decodeIfPresent(Bool.self, forKey: .flipVertical) ?? false
        colorMixer = try container.decodeIfPresent(ColorMixerAdjustments.self, forKey: .colorMixer) ?? ColorMixerAdjustments()
    }

    var effectiveSpotHealPoints: [SpotHealPoint] {
        if !spotHealPoints.isEmpty {
            return spotHealPoints
        }

        return Self.normalizedSpotHealPoints(
            points: [],
            legacyAmount: spotHealAmount,
            legacyX: spotHealX,
            legacyY: spotHealY,
            legacyRadius: spotHealRadius,
            legacyFeather: spotHealFeather,
            legacySourceOffsetX: spotHealSourceOffsetX,
            legacySourceOffsetY: spotHealSourceOffsetY
        )
    }

    mutating func resetSpotHeal() {
        spotHealAmount = 0
        spotHealX = 0.5
        spotHealY = 0.5
        spotHealRadius = 0.06
        spotHealFeather = 0.04
        spotHealSourceOffsetX = 0.08
        spotHealSourceOffsetY = 0
        spotHealPoints = []
    }

    private static func normalizedSpotHealPoints(
        points: [SpotHealPoint],
        legacyAmount: Double,
        legacyX: Double,
        legacyY: Double,
        legacyRadius: Double,
        legacyFeather: Double,
        legacySourceOffsetX: Double,
        legacySourceOffsetY: Double
    ) -> [SpotHealPoint] {
        if !points.isEmpty {
            return points
        }

        guard legacyAmount > 0 else {
            return []
        }

        return [
            SpotHealPoint(
                amount: legacyAmount,
                x: legacyX,
                y: legacyY,
                radius: legacyRadius,
                feather: legacyFeather,
                sourceOffsetX: legacySourceOffsetX,
                sourceOffsetY: legacySourceOffsetY
            )
        ]
    }

    mutating func invertLinearGradientDirection() {
        let startY = linearStartY
        linearStartY = linearEndY
        linearEndY = startY
    }

    mutating func applyBlackAndWhiteLook() {
        saturation = 0
        vibrance = 0
        contrast = max(contrast, 1.18)
        clarity = max(clarity, 0.22)
        blacks = min(blacks, -0.08)
        whites = max(whites, 0.08)
        vignette = max(vignette, 0.12)
    }

    mutating func resetCropTransform() {
        straighten = 0
        perspectiveVertical = 0
        perspectiveHorizontal = 0
        rotationTurns = 0
        cropAspect = .original
        cropCenterX = 0.5
        cropCenterY = 0.5
        flipHorizontal = false
        flipVertical = false
    }

    mutating func resetLensCorrections() {
        lensDistortionCorrection = 0
        chromaticAberrationReduction = 0
        lensVignetteCorrection = 0
    }

    mutating func resetToneAdjustments() {
        exposure = 0
        highlights = 0
        shadows = 0
        whites = 0
        blacks = 0
        contrast = 1
        saturation = 1
        hue = 0
        warmth = 0
        tint = 0
        vibrance = 0
        fade = 0
        texture = 0
        clarity = 0
        dehaze = 0
        noiseReduction = 0
        sharpness = 0
        vignette = 0
        vignetteRadius = 0.5
        grainAmount = 0
        grainSize = 0.35
        grainRoughness = 0.5
        toneCurveShadows = 0
        toneCurveDarks = 0
        toneCurveLights = 0
        toneCurveHighlights = 0
        colorGradeShadowsHue = 220
        colorGradeShadowsSaturation = 0
        colorGradeMidtonesHue = 40
        colorGradeMidtonesSaturation = 0
        colorGradeHighlightsHue = 45
        colorGradeHighlightsSaturation = 0
    }
}

struct ColorMixerAdjustments: Codable, Equatable {
    var redHue: Double = 0
    var orangeHue: Double = 0
    var yellowHue: Double = 0
    var greenHue: Double = 0
    var aquaHue: Double = 0
    var blueHue: Double = 0
    var purpleHue: Double = 0
    var magentaHue: Double = 0
    var red: Double = 0
    var orange: Double = 0
    var yellow: Double = 0
    var green: Double = 0
    var aqua: Double = 0
    var blue: Double = 0
    var purple: Double = 0
    var magenta: Double = 0
    var redLuminance: Double = 0
    var orangeLuminance: Double = 0
    var yellowLuminance: Double = 0
    var greenLuminance: Double = 0
    var aquaLuminance: Double = 0
    var blueLuminance: Double = 0
    var purpleLuminance: Double = 0
    var magentaLuminance: Double = 0

    private enum CodingKeys: String, CodingKey {
        case redHue
        case orangeHue
        case yellowHue
        case greenHue
        case aquaHue
        case blueHue
        case purpleHue
        case magentaHue
        case red
        case orange
        case yellow
        case green
        case aqua
        case blue
        case purple
        case magenta
        case redLuminance
        case orangeLuminance
        case yellowLuminance
        case greenLuminance
        case aquaLuminance
        case blueLuminance
        case purpleLuminance
        case magentaLuminance
    }

    init(
        redHue: Double = 0,
        orangeHue: Double = 0,
        yellowHue: Double = 0,
        greenHue: Double = 0,
        aquaHue: Double = 0,
        blueHue: Double = 0,
        purpleHue: Double = 0,
        magentaHue: Double = 0,
        red: Double = 0,
        orange: Double = 0,
        yellow: Double = 0,
        green: Double = 0,
        aqua: Double = 0,
        blue: Double = 0,
        purple: Double = 0,
        magenta: Double = 0,
        redLuminance: Double = 0,
        orangeLuminance: Double = 0,
        yellowLuminance: Double = 0,
        greenLuminance: Double = 0,
        aquaLuminance: Double = 0,
        blueLuminance: Double = 0,
        purpleLuminance: Double = 0,
        magentaLuminance: Double = 0
    ) {
        self.redHue = redHue
        self.orangeHue = orangeHue
        self.yellowHue = yellowHue
        self.greenHue = greenHue
        self.aquaHue = aquaHue
        self.blueHue = blueHue
        self.purpleHue = purpleHue
        self.magentaHue = magentaHue
        self.red = red
        self.orange = orange
        self.yellow = yellow
        self.green = green
        self.aqua = aqua
        self.blue = blue
        self.purple = purple
        self.magenta = magenta
        self.redLuminance = redLuminance
        self.orangeLuminance = orangeLuminance
        self.yellowLuminance = yellowLuminance
        self.greenLuminance = greenLuminance
        self.aquaLuminance = aquaLuminance
        self.blueLuminance = blueLuminance
        self.purpleLuminance = purpleLuminance
        self.magentaLuminance = magentaLuminance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        redHue = try container.decodeIfPresent(Double.self, forKey: .redHue) ?? 0
        orangeHue = try container.decodeIfPresent(Double.self, forKey: .orangeHue) ?? 0
        yellowHue = try container.decodeIfPresent(Double.self, forKey: .yellowHue) ?? 0
        greenHue = try container.decodeIfPresent(Double.self, forKey: .greenHue) ?? 0
        aquaHue = try container.decodeIfPresent(Double.self, forKey: .aquaHue) ?? 0
        blueHue = try container.decodeIfPresent(Double.self, forKey: .blueHue) ?? 0
        purpleHue = try container.decodeIfPresent(Double.self, forKey: .purpleHue) ?? 0
        magentaHue = try container.decodeIfPresent(Double.self, forKey: .magentaHue) ?? 0
        red = try container.decodeIfPresent(Double.self, forKey: .red) ?? 0
        orange = try container.decodeIfPresent(Double.self, forKey: .orange) ?? 0
        yellow = try container.decodeIfPresent(Double.self, forKey: .yellow) ?? 0
        green = try container.decodeIfPresent(Double.self, forKey: .green) ?? 0
        aqua = try container.decodeIfPresent(Double.self, forKey: .aqua) ?? 0
        blue = try container.decodeIfPresent(Double.self, forKey: .blue) ?? 0
        purple = try container.decodeIfPresent(Double.self, forKey: .purple) ?? 0
        magenta = try container.decodeIfPresent(Double.self, forKey: .magenta) ?? 0
        redLuminance = try container.decodeIfPresent(Double.self, forKey: .redLuminance) ?? 0
        orangeLuminance = try container.decodeIfPresent(Double.self, forKey: .orangeLuminance) ?? 0
        yellowLuminance = try container.decodeIfPresent(Double.self, forKey: .yellowLuminance) ?? 0
        greenLuminance = try container.decodeIfPresent(Double.self, forKey: .greenLuminance) ?? 0
        aquaLuminance = try container.decodeIfPresent(Double.self, forKey: .aquaLuminance) ?? 0
        blueLuminance = try container.decodeIfPresent(Double.self, forKey: .blueLuminance) ?? 0
        purpleLuminance = try container.decodeIfPresent(Double.self, forKey: .purpleLuminance) ?? 0
        magentaLuminance = try container.decodeIfPresent(Double.self, forKey: .magentaLuminance) ?? 0
    }

    var hasAdjustments: Bool {
        redHue != 0 ||
            orangeHue != 0 ||
            yellowHue != 0 ||
            greenHue != 0 ||
            aquaHue != 0 ||
            blueHue != 0 ||
            purpleHue != 0 ||
            magentaHue != 0 ||
            red != 0 ||
            orange != 0 ||
            yellow != 0 ||
            green != 0 ||
            aqua != 0 ||
            blue != 0 ||
            purple != 0 ||
            magenta != 0 ||
            redLuminance != 0 ||
            orangeLuminance != 0 ||
            yellowLuminance != 0 ||
            greenLuminance != 0 ||
            aquaLuminance != 0 ||
            blueLuminance != 0 ||
            purpleLuminance != 0 ||
            magentaLuminance != 0
    }
}

struct AdjustmentHistoryEntry {
    let photoID: UUID
    let before: PhotoAdjustments
    let after: PhotoAdjustments
}

enum CropAspect: String, CaseIterable, Codable, Identifiable {
    case original = "Original"
    case square = "1:1"
    case twoByThree = "2:3"
    case portrait = "4:5"
    case threeByFour = "3:4"
    case classic = "3:2"
    case fourByThree = "4:3"
    case fiveByFour = "5:4"
    case wide = "16:9"

    var id: String {
        rawValue
    }

    var ratio: CGFloat? {
        switch self {
        case .original:
            nil
        case .square:
            1
        case .twoByThree:
            2 / 3
        case .portrait:
            4 / 5
        case .threeByFour:
            3 / 4
        case .classic:
            3 / 2
        case .fourByThree:
            4 / 3
        case .fiveByFour:
            5 / 4
        case .wide:
            16 / 9
        }
    }
}

struct CatalogFile: Codable {
    var entries: [CatalogEntry]
}

struct CatalogEntry: Codable {
    let id: UUID
    let path: String
    var adjustments: PhotoAdjustments
    var rating: Int
    var flag: PhotoFlag
    var colorLabel: PhotoColorLabel?
    var importedAt: Date?
}

struct PhotoMetadata: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64?
    let formatName: String?
    let isRaw: Bool
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let iso: Int?
    let aperture: Double?
    let shutterSpeed: Double?
    let focalLength: Double?
    let captureDate: Date?

    var dimensionsText: String {
        "\(pixelWidth) x \(pixelHeight)"
    }

    var megapixelsText: String {
        let megapixels = Double(pixelWidth * pixelHeight) / 1_000_000
        return String(format: "%.1f MP", megapixels)
    }

    var fileSizeText: String {
        guard let fileSize else {
            return "Unknown size"
        }

        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formatText: String {
        if isRaw {
            return "RAW"
        }

        return formatName ?? "Image"
    }

    var cameraText: String? {
        [cameraMake, cameraModel]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfEmpty
    }

    var exposureText: String? {
        var parts: [String] = []

        if let shutterSpeed {
            if shutterSpeed >= 1 {
                parts.append(String(format: "%.1fs", shutterSpeed))
            } else if shutterSpeed > 0 {
                parts.append("1/\(Int(round(1 / shutterSpeed)))s")
            }
        }

        if let aperture {
            parts.append(String(format: "f/%.1f", aperture))
        }

        if let iso {
            parts.append("ISO \(iso)")
        }

        return parts.joined(separator: "  ").nilIfEmpty
    }

    var focalLengthText: String? {
        focalLength.map { String(format: "%.0f mm", $0) }
    }

    var captureDateText: String? {
        guard let captureDate else {
            return nil
        }

        return captureDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
