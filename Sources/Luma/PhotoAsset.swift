import AppKit
import Foundation

struct PhotoAsset: Identifiable, Equatable {
    let id = UUID()
    let url: URL
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

    static let neutral = PhotoAdjustments()
}
