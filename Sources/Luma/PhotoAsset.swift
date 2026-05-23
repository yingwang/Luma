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
    var contrast: Double = 1
    var saturation: Double = 1
    var warmth: Double = 0
    var vibrance: Double = 0
    var sharpness: Double = 0
    var rotationTurns: Int = 0

    static let neutral = PhotoAdjustments()
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
