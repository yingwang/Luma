import AppKit
import Foundation

struct PhotoAsset: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let metadata: PhotoMetadata?
    let histogramBins: [Double]?
    var thumbnail: NSImage?
    var adjustments = PhotoAdjustments()
    var rating: Int = 0
    var flag: PhotoFlag = .none

    var fileName: String {
        url.lastPathComponent
    }

    init(
        id: UUID = UUID(),
        url: URL,
        metadata: PhotoMetadata?,
        histogramBins: [Double]?,
        thumbnail: NSImage? = nil,
        adjustments: PhotoAdjustments = .neutral,
        rating: Int = 0,
        flag: PhotoFlag = .none
    ) {
        self.id = id
        self.url = url
        self.metadata = metadata
        self.histogramBins = histogramBins
        self.thumbnail = thumbnail
        self.adjustments = adjustments
        self.rating = rating
        self.flag = flag
    }
}

enum PhotoFlag: String, CaseIterable, Codable, Equatable {
    case none = "None"
    case picked = "Picked"
    case rejected = "Rejected"
}

enum LibraryFilter: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case picked = "Picked"
    case rejected = "Rejected"
    case rated = "Rated"

    var id: String {
        rawValue
    }
}

enum PhotoPreset: String, CaseIterable, Identifiable {
    case neutral = "Neutral"
    case vivid = "Vivid"
    case softPortrait = "Soft Portrait"
    case blackAndWhite = "Black & White"
    case warmFilm = "Warm Film"

    var id: String {
        rawValue
    }

    var adjustments: PhotoAdjustments {
        switch self {
        case .neutral:
            return .neutral
        case .vivid:
            return PhotoAdjustments(exposure: 0.1, contrast: 1.18, saturation: 1.12, warmth: 80, vibrance: 0.35, sharpness: 0.7)
        case .softPortrait:
            return PhotoAdjustments(exposure: 0.2, contrast: 0.92, saturation: 0.96, warmth: 180, vibrance: 0.08, sharpness: 0.25)
        case .blackAndWhite:
            return PhotoAdjustments(exposure: 0, contrast: 1.25, saturation: 0, warmth: 0, vibrance: 0, sharpness: 0.45)
        case .warmFilm:
            return PhotoAdjustments(exposure: 0.05, contrast: 1.08, saturation: 0.94, warmth: 420, vibrance: 0.18, sharpness: 0.35)
        }
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
    var clarity: Double = 0
    var dehaze: Double = 0
    var noiseReduction: Double = 0
    var sharpness: Double = 0
    var vignette: Double = 0
    var straighten: Double = 0
    var rotationTurns: Int = 0
    var cropAspect: CropAspect = .original
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
        case clarity
        case dehaze
        case noiseReduction
        case sharpness
        case vignette
        case straighten
        case rotationTurns
        case cropAspect
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
        clarity: Double = 0,
        dehaze: Double = 0,
        noiseReduction: Double = 0,
        sharpness: Double = 0,
        vignette: Double = 0,
        straighten: Double = 0,
        rotationTurns: Int = 0,
        cropAspect: CropAspect = .original,
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
        self.clarity = clarity
        self.dehaze = dehaze
        self.noiseReduction = noiseReduction
        self.sharpness = sharpness
        self.vignette = vignette
        self.straighten = straighten
        self.rotationTurns = rotationTurns
        self.cropAspect = cropAspect
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
        clarity = try container.decodeIfPresent(Double.self, forKey: .clarity) ?? 0
        dehaze = try container.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0
        noiseReduction = try container.decodeIfPresent(Double.self, forKey: .noiseReduction) ?? 0
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        vignette = try container.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        straighten = try container.decodeIfPresent(Double.self, forKey: .straighten) ?? 0
        rotationTurns = try container.decodeIfPresent(Int.self, forKey: .rotationTurns) ?? 0
        cropAspect = try container.decodeIfPresent(CropAspect.self, forKey: .cropAspect) ?? .original
        colorMixer = try container.decodeIfPresent(ColorMixerAdjustments.self, forKey: .colorMixer) ?? ColorMixerAdjustments()
    }
}

struct ColorMixerAdjustments: Codable, Equatable {
    var red: Double = 0
    var orange: Double = 0
    var yellow: Double = 0
    var green: Double = 0
    var aqua: Double = 0
    var blue: Double = 0
    var purple: Double = 0
    var magenta: Double = 0

    var hasAdjustments: Bool {
        red != 0 || orange != 0 || yellow != 0 || green != 0 || aqua != 0 || blue != 0 || purple != 0 || magenta != 0
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
    case portrait = "4:5"
    case classic = "3:2"
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
        case .portrait:
            4 / 5
        case .classic:
            3 / 2
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
