import AppKit
import Foundation

struct PhotoAsset: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let metadata: PhotoMetadata?
    var thumbnail: NSImage?
    var adjustments = PhotoAdjustments()

    var fileName: String {
        url.lastPathComponent
    }
}

struct PhotoAdjustments: Equatable {
    var exposure: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var warmth: Double = 0
    var vibrance: Double = 0
    var sharpness: Double = 0
    var rotationTurns: Int = 0

    static let neutral = PhotoAdjustments()
}

struct PhotoMetadata: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64?

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
}
