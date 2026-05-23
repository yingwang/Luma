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
    var contrast: Double = 1
    var saturation: Double = 1
    var warmth: Double = 0
    var tint: Double = 0
    var vibrance: Double = 0
    var clarity: Double = 0
    var dehaze: Double = 0
    var noiseReduction: Double = 0
    var sharpness: Double = 0
    var vignette: Double = 0
    var rotationTurns: Int = 0
    var cropAspect: CropAspect = .original

    static let neutral = PhotoAdjustments()

    private enum CodingKeys: String, CodingKey {
        case exposure
        case highlights
        case shadows
        case contrast
        case saturation
        case warmth
        case tint
        case vibrance
        case clarity
        case dehaze
        case noiseReduction
        case sharpness
        case vignette
        case rotationTurns
        case cropAspect
    }

    init(
        exposure: Double = 0,
        highlights: Double = 0,
        shadows: Double = 0,
        contrast: Double = 1,
        saturation: Double = 1,
        warmth: Double = 0,
        tint: Double = 0,
        vibrance: Double = 0,
        clarity: Double = 0,
        dehaze: Double = 0,
        noiseReduction: Double = 0,
        sharpness: Double = 0,
        vignette: Double = 0,
        rotationTurns: Int = 0,
        cropAspect: CropAspect = .original
    ) {
        self.exposure = exposure
        self.highlights = highlights
        self.shadows = shadows
        self.contrast = contrast
        self.saturation = saturation
        self.warmth = warmth
        self.tint = tint
        self.vibrance = vibrance
        self.clarity = clarity
        self.dehaze = dehaze
        self.noiseReduction = noiseReduction
        self.sharpness = sharpness
        self.vignette = vignette
        self.rotationTurns = rotationTurns
        self.cropAspect = cropAspect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        warmth = try container.decodeIfPresent(Double.self, forKey: .warmth) ?? 0
        tint = try container.decodeIfPresent(Double.self, forKey: .tint) ?? 0
        vibrance = try container.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
        clarity = try container.decodeIfPresent(Double.self, forKey: .clarity) ?? 0
        dehaze = try container.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0
        noiseReduction = try container.decodeIfPresent(Double.self, forKey: .noiseReduction) ?? 0
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0
        vignette = try container.decodeIfPresent(Double.self, forKey: .vignette) ?? 0
        rotationTurns = try container.decodeIfPresent(Int.self, forKey: .rotationTurns) ?? 0
        cropAspect = try container.decodeIfPresent(CropAspect.self, forKey: .cropAspect) ?? .original
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
}
