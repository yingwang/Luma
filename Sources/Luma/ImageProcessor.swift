import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

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
        let typeIdentifier = CGImageSourceGetType(source) as String?
        let type = typeIdentifier.flatMap(UTType.init)
        let rawType = UTType("public.camera-raw-image")
        let rawExtensions: Set<String> = ["3fr", "arw", "cr2", "cr3", "dcr", "dng", "erf", "fff", "iiq", "kdc", "mef", "mos", "mrw", "nef", "nrw", "orf", "pef", "raf", "raw", "rw2", "rwl", "sr2", "srf", "x3f"]
        let conformsToRaw = if let type, let rawType {
            type.conforms(to: rawType)
        } else {
            false
        }
        let isRaw = conformsToRaw
            || rawExtensions.contains(url.pathExtension.lowercased())

        return PhotoMetadata(
            pixelWidth: width,
            pixelHeight: height,
            fileSize: fileSize,
            formatName: type?.preferredFilenameExtension?.uppercased(),
            isRaw: isRaw
        )
    }

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 360) -> NSImage? {
        guard let cgImage = thumbnailCGImage(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: .zero)
    }

    func luminanceHistogram(for url: URL, binCount: Int = 48) -> [Double]? {
        guard binCount > 0, let cgImage = thumbnailCGImage(for: url, maxPixelSize: 256) else {
            return nil
        }

        let width = 128
        let height = 128
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var bins = [Double](repeating: 0, count: binCount)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let bin = min(binCount - 1, Int((luminance / 256) * Double(binCount)))
            bins[bin] += 1
        }

        guard let maxValue = bins.max(), maxValue > 0 else {
            return bins
        }

        return bins.map { $0 / maxValue }
    }

    private func thumbnailCGImage(for url: URL, maxPixelSize: CGFloat) -> CGImage? {
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

        return cgImage
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

        image = centerCrop(image, aspect: adjustments.cropAspect)

        if adjustments.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(adjustments.exposure)
            image = filter.outputImage ?? image
        }

        if adjustments.highlights != 0 || adjustments.shadows != 0, let filter = CIFilter(name: "CIHighlightShadowAdjust") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(1 + adjustments.highlights, forKey: "inputHighlightAmount")
            filter.setValue(adjustments.shadows, forKey: "inputShadowAmount")
            image = filter.outputImage ?? image
        }

        if adjustments.contrast != 1 || adjustments.saturation != 1 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = Float(adjustments.contrast)
            filter.saturation = Float(adjustments.saturation)
            image = filter.outputImage ?? image
        }

        if adjustments.dehaze != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = Float(1 + adjustments.dehaze * 0.35)
            filter.saturation = Float(1 + adjustments.dehaze * 0.12)
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

        if adjustments.clarity > 0, let filter = CIFilter(name: "CIUnsharpMask") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(2 + adjustments.clarity * 4, forKey: kCIInputRadiusKey)
            filter.setValue(adjustments.clarity * 0.7, forKey: kCIInputIntensityKey)
            image = filter.outputImage ?? image
        }

        if adjustments.sharpness > 0, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            image = filter.outputImage ?? image
        }

        if adjustments.vignette != 0, let filter = CIFilter(name: "CIVignette") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(abs(adjustments.vignette) * 1.5, forKey: kCIInputIntensityKey)
            filter.setValue(1 + abs(adjustments.vignette) * 2.5, forKey: kCIInputRadiusKey)
            image = filter.outputImage ?? image
        }

        image = rotate(image, turns: adjustments.rotationTurns)

        return image
    }

    private func centerCrop(_ image: CIImage, aspect: CropAspect) -> CIImage {
        guard let targetRatio = aspect.ratio else {
            return normalizeExtent(image)
        }

        let extent = image.extent
        let currentRatio = extent.width / extent.height
        let cropRect: CGRect

        if currentRatio > targetRatio {
            let width = extent.height * targetRatio
            cropRect = CGRect(
                x: extent.midX - width / 2,
                y: extent.minY,
                width: width,
                height: extent.height
            )
        } else {
            let height = extent.width / targetRatio
            cropRect = CGRect(
                x: extent.minX,
                y: extent.midY - height / 2,
                width: extent.width,
                height: height
            )
        }

        return normalizeExtent(image.cropped(to: cropRect))
    }

    private func rotate(_ image: CIImage, turns: Int) -> CIImage {
        let normalizedTurns = ((turns % 4) + 4) % 4
        let extent = image.extent

        let rotated = switch normalizedTurns {
        case 1:
            image.transformed(
                by: CGAffineTransform(rotationAngle: .pi / 2)
                    .translatedBy(x: 0, y: -extent.height)
            )
        case 2:
            image.transformed(
                by: CGAffineTransform(rotationAngle: .pi)
                    .translatedBy(x: -extent.width, y: -extent.height)
            )
        case 3:
            image.transformed(
                by: CGAffineTransform(rotationAngle: -.pi / 2)
                    .translatedBy(x: -extent.width, y: 0)
            )
        default:
            image
        }

        return normalizeExtent(rotated)
    }

    private func normalizeExtent(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
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
