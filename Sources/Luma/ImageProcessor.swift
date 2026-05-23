import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO

final class ImageProcessor: @unchecked Sendable {
    static let shared = ImageProcessor()

    private let context: CIContext

    private init() {
        context = CIContext(options: [
            .cacheIntermediates: false
        ])
    }

    func canReadImage(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }

        return CGImageSourceGetCount(source) > 0
    }

    func metadata(for url: URL) -> PhotoMetadata? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resourceValues?.fileSize.map(Int64.init)

        return PhotoMetadata(pixelWidth: width, pixelHeight: height, fileSize: fileSize)
    }

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 360) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }

    func preview(for url: URL, adjustments: PhotoAdjustments, maxPixelSize: CGFloat = 2400) -> NSImage? {
        guard let image = processedImage(for: url, adjustments: adjustments) else {
            return nil
        }

        let scale = min(1, maxPixelSize / max(image.extent.width, image.extent.height))
        let output = scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image

        return render(output)
    }

    func exportJPEG(from url: URL, adjustments: PhotoAdjustments, to destination: URL, quality: CGFloat = 0.92) throws {
        guard
            let image = processedImage(for: url, adjustments: adjustments),
            let cgImage = context.createCGImage(image, from: image.extent),
            let destinationRef = CGImageDestinationCreateWithURL(
                destination as CFURL,
                "public.jpeg" as CFString,
                1,
                nil
            )
        else {
            throw LumaError.exportFailed
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destinationRef, cgImage, properties as CFDictionary)

        if !CGImageDestinationFinalize(destinationRef) {
            throw LumaError.exportFailed
        }
    }

    private func processedImage(for url: URL, adjustments: PhotoAdjustments) -> CIImage? {
        guard var image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
            return nil
        }

        if adjustments.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(adjustments.exposure)
            image = filter.outputImage ?? image
        }

        if adjustments.contrast != 1 || adjustments.saturation != 1 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = Float(adjustments.contrast)
            filter.saturation = Float(adjustments.saturation)
            image = filter.outputImage ?? image
        }

        if adjustments.warmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500 - adjustments.warmth, y: 0)
            filter.targetNeutral = CIVector(x: 6500, y: 0)
            image = filter.outputImage ?? image
        }

        if adjustments.vibrance != 0, let filter = CIFilter(name: "CIVibrance") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.vibrance, forKey: kCIInputAmountKey)
            image = filter.outputImage ?? image
        }

        if adjustments.sharpness > 0, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            image = filter.outputImage ?? image
        }

        image = rotate(image, turns: adjustments.rotationTurns)

        return image
    }

    private func rotate(_ image: CIImage, turns: Int) -> CIImage {
        let normalizedTurns = ((turns % 4) + 4) % 4
        let extent = image.extent

        switch normalizedTurns {
        case 1:
            return image.transformed(
                by: CGAffineTransform(rotationAngle: .pi / 2)
                    .translatedBy(x: 0, y: -extent.height)
            )
        case 2:
            return image.transformed(
                by: CGAffineTransform(rotationAngle: .pi)
                    .translatedBy(x: -extent.width, y: -extent.height)
            )
        case 3:
            return image.transformed(
                by: CGAffineTransform(rotationAngle: -.pi / 2)
                    .translatedBy(x: -extent.width, y: 0)
            )
        default:
            return image
        }
    }

    private func render(_ image: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: image.extent.width, height: image.extent.height))
    }
}

enum LumaError: LocalizedError {
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            "Luma could not export the selected photo."
        }
    }
}
