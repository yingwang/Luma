import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

final class ImageProcessor: @unchecked Sendable {
    static let shared = ImageProcessor()

    private let context: CIContext
    private let outputColorSpace: CGColorSpace
    private let previewCache = NSCache<NSString, NSImage>()
    private let thumbnailCache = NSCache<NSString, NSImage>()

    private init() {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        outputColorSpace = colorSpace
        context = CIContext(options: [
            .cacheIntermediates: false,
            .outputColorSpace: colorSpace
        ])
        previewCache.countLimit = 80
        previewCache.totalCostLimit = 256 * 1024 * 1024
        thumbnailCache.countLimit = 1_200
        thumbnailCache.totalCostLimit = 160 * 1024 * 1024
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

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
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
            isRaw: isRaw,
            cameraMake: tiff?[kCGImagePropertyTIFFMake] as? String,
            cameraModel: tiff?[kCGImagePropertyTIFFModel] as? String,
            lensModel: exif?[kCGImagePropertyExifLensModel] as? String,
            iso: isoValue(from: exif?[kCGImagePropertyExifISOSpeedRatings]),
            aperture: exif?[kCGImagePropertyExifFNumber] as? Double,
            shutterSpeed: exif?[kCGImagePropertyExifExposureTime] as? Double,
            focalLength: exif?[kCGImagePropertyExifFocalLength] as? Double,
            captureDate: captureDate(from: exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
        )
    }

    func thumbnail(for url: URL, maxPixelSize: CGFloat = 360) -> NSImage? {
        let cacheKey = imageCacheKey(for: url, pixelSize: maxPixelSize, namespace: "thumbnail")
        if let cachedImage = thumbnailCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let cgImage = thumbnailCGImage(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }

        let image = NSImage(cgImage: cgImage, size: .zero)
        thumbnailCache.setObject(image, forKey: cacheKey, cost: imageCost(image))
        return image
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

    func rgbHistogram(for url: URL, binCount: Int = 48) -> RGBHistogram? {
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

        var redBins = [Double](repeating: 0, count: binCount)
        var greenBins = [Double](repeating: 0, count: binCount)
        var blueBins = [Double](repeating: 0, count: binCount)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let redBin = min(binCount - 1, Int((Double(pixels[index]) / 256) * Double(binCount)))
            let greenBin = min(binCount - 1, Int((Double(pixels[index + 1]) / 256) * Double(binCount)))
            let blueBin = min(binCount - 1, Int((Double(pixels[index + 2]) / 256) * Double(binCount)))

            redBins[redBin] += 1
            greenBins[greenBin] += 1
            blueBins[blueBin] += 1
        }

        return RGBHistogram(
            red: normalizedHistogram(redBins),
            green: normalizedHistogram(greenBins),
            blue: normalizedHistogram(blueBins)
        )
    }

    func clearImageCaches() {
        previewCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }

    private func normalizedHistogram(_ bins: [Double]) -> [Double] {
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

    func preview(
        for url: URL,
        adjustments: PhotoAdjustments,
        maxPixelSize: CGFloat = 2400,
        showClippingWarnings: Bool = false
    ) -> NSImage? {
        let cacheKey = previewCacheKey(
            for: url,
            adjustments: adjustments,
            maxPixelSize: maxPixelSize,
            showClippingWarnings: showClippingWarnings
        )
        if let cachedImage = previewCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let image = processedImage(for: url, adjustments: adjustments) else {
            return nil
        }

        let scale = min(1, maxPixelSize / max(image.extent.width, image.extent.height))
        let output = scale < 1 ? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : image

        guard let renderedImage = render(output) else {
            return nil
        }

        let finalImage = showClippingWarnings
            ? clippingWarningPreview(from: renderedImage)
            : renderedImage

        previewCache.setObject(finalImage, forKey: cacheKey, cost: imageCost(finalImage))
        return finalImage
    }

    func exportJPEG(
        from url: URL,
        adjustments: PhotoAdjustments,
        to destination: URL,
        quality: CGFloat = 0.92,
        maxLongEdge: CGFloat? = nil
    ) throws {
        try exportImage(
            from: url,
            adjustments: adjustments,
            to: destination,
            format: .jpeg,
            quality: quality,
            maxLongEdge: maxLongEdge
        )
    }

    func exportImage(
        from url: URL,
        adjustments: PhotoAdjustments,
        to destination: URL,
        format: ExportFormat,
        quality: CGFloat = 0.92,
        maxLongEdge: CGFloat? = nil
    ) throws {
        guard
            let processedImage = processedImage(for: url, adjustments: adjustments),
            let image = scaledImage(processedImage, maxLongEdge: maxLongEdge),
            let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: outputColorSpace),
            let destinationRef = CGImageDestinationCreateWithURL(
                destination as CFURL,
                format.typeIdentifier as CFString,
                1,
                nil
            )
        else {
            throw LumaError.exportFailed
        }

        let properties: [CFString: Any] = switch format {
        case .jpeg:
            [kCGImageDestinationLossyCompressionQuality: quality]
        case .png, .tiff:
            [:]
        }

        CGImageDestinationAddImage(destinationRef, cgImage, properties as CFDictionary)

        if !CGImageDestinationFinalize(destinationRef) {
            throw LumaError.exportFailed
        }
    }

    private func processedImage(for url: URL, adjustments: PhotoAdjustments) -> CIImage? {
        guard var image = loadBaseImage(at: url) else {
            return nil
        }

        image = centerCrop(image, aspect: adjustments.cropAspect)
        image = straighten(image, degrees: adjustments.straighten)

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

        if adjustments.whites != 0 || adjustments.blacks != 0, let filter = CIFilter(name: "CIToneCurve") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 0, y: clipped(0.08 * adjustments.blacks)), forKey: "inputPoint0")
            filter.setValue(CIVector(x: 0.25, y: clipped(0.25 + 0.18 * adjustments.blacks)), forKey: "inputPoint1")
            filter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
            filter.setValue(CIVector(x: 0.75, y: clipped(0.75 + 0.18 * adjustments.whites)), forKey: "inputPoint3")
            filter.setValue(CIVector(x: 1, y: clipped(1 + 0.08 * adjustments.whites)), forKey: "inputPoint4")
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

        if adjustments.hue != 0 {
            let filter = CIFilter.hueAdjust()
            filter.inputImage = image
            filter.angle = Float(adjustments.hue * .pi / 180)
            image = filter.outputImage ?? image
        }

        if adjustments.warmth != 0 || adjustments.tint != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500 - adjustments.warmth, y: -adjustments.tint)
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

        if adjustments.noiseReduction > 0, let filter = CIFilter(name: "CINoiseReduction") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.noiseReduction * 0.08, forKey: "inputNoiseLevel")
            filter.setValue(0.3, forKey: kCIInputSharpnessKey)
            image = filter.outputImage ?? image
        }

        if adjustments.beautySmooth > 0, let filter = CIFilter(name: "CINoiseReduction") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.02 + adjustments.beautySmooth * 0.12, forKey: "inputNoiseLevel")
            filter.setValue(0.12, forKey: kCIInputSharpnessKey)
            image = filter.outputImage ?? image
        }

        if adjustments.beautyWrinkle > 0, let filter = CIFilter(name: "CIGaussianBlur") {
            let original = image
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.beautyWrinkle * 1.8, forKey: kCIInputRadiusKey)

            if let softened = filter.outputImage?.cropped(to: original.extent), let blend = CIFilter(name: "CIScreenBlendMode") {
                blend.setValue(softened, forKey: kCIInputImageKey)
                blend.setValue(original, forKey: kCIInputBackgroundImageKey)
                image = blend.outputImage ?? image
            }
        }

        if adjustments.beautyBlemish > 0, let median = CIFilter(name: "CIMedianFilter") {
            let original = image
            median.setValue(image, forKey: kCIInputImageKey)

            if let cleaned = median.outputImage?.cropped(to: original.extent), let blend = CIFilter(name: "CISoftLightBlendMode") {
                blend.setValue(cleaned, forKey: kCIInputImageKey)
                blend.setValue(original, forKey: kCIInputBackgroundImageKey)
                image = blend.outputImage ?? image
            }
        }

        if adjustments.beautyBrighten > 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.brightness = Float(adjustments.beautyBrighten * 0.12)
            filter.saturation = Float(1 + adjustments.beautyBrighten * 0.05)
            image = filter.outputImage ?? image
        }

        if adjustments.beautyWhiten > 0, let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(image, forKey: kCIInputImageKey)
            let lift = CGFloat(adjustments.beautyWhiten * 0.10)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: lift, y: lift, z: lift * 0.92, w: 0), forKey: "inputBiasVector")
            image = filter.outputImage ?? image
        }

        if adjustments.beautyRosy > 0, let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(image, forKey: kCIInputImageKey)
            let redLift = CGFloat(adjustments.beautyRosy * 0.08)
            let blueLift = CGFloat(adjustments.beautyRosy * 0.025)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: redLift, y: 0, z: blueLift, w: 0), forKey: "inputBiasVector")
            image = filter.outputImage ?? image
        }

        if adjustments.beautyWarmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500 - adjustments.beautyWarmth * 700, y: 0)
            filter.targetNeutral = CIVector(x: 6500, y: 0)
            image = filter.outputImage ?? image
        }

        if adjustments.beautyGlow > 0, let filter = CIFilter(name: "CIBloom") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.beautyGlow * 0.45, forKey: kCIInputIntensityKey)
            filter.setValue(2 + adjustments.beautyGlow * 8, forKey: kCIInputRadiusKey)
            image = filter.outputImage ?? image
        }

        if adjustments.beautySoften > 0, let filter = CIFilter(name: "CIGaussianBlur") {
            let original = image
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.beautySoften * 2.5, forKey: kCIInputRadiusKey)

            if let blurred = filter.outputImage?.cropped(to: original.extent), let blend = CIFilter(name: "CISoftLightBlendMode") {
                blend.setValue(blurred, forKey: kCIInputImageKey)
                blend.setValue(original, forKey: kCIInputBackgroundImageKey)
                image = blend.outputImage ?? image
            }
        }

        if adjustments.beautyDetail > 0, let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(adjustments.beautyDetail * 0.8, forKey: kCIInputSharpnessKey)
            image = filter.outputImage ?? image
        }

        image = applyEyeEnlarge(adjustments.eyeEnlarge, to: image)
        image = applyBodySlim(adjustments.bodySlim, to: image)
        image = applyFaceSlim(adjustments.faceSlim, to: image)
        image = applyRadialExposure(adjustments, to: image)
        image = applyLinearExposure(adjustments, to: image)
        image = applySpotHeal(adjustments, to: image)

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

        if adjustments.colorMixer.hasAdjustments {
            image = applyColorMixer(adjustments.colorMixer, to: image)
        }

        image = rotate(image, turns: adjustments.rotationTurns)
        image = flip(image, horizontal: adjustments.flipHorizontal, vertical: adjustments.flipVertical)

        return image
    }

    // RAW files need a demosaicing pass, which CIImage(contentsOf:) does not do.
    // Route them through CIRAWFilter for a proper decode and fall back to the
    // standard loader for everything else (the initializer returns nil for
    // formats that are not RAW).
    private func loadBaseImage(at url: URL) -> CIImage? {
        if let rawFilter = CIRAWFilter(imageURL: url) {
            return rawFilter.outputImage
        }

        return CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    }

    private func scaledImage(_ image: CIImage, maxLongEdge: CGFloat?) -> CIImage? {
        guard let maxLongEdge, maxLongEdge > 0 else {
            return image
        }

        let longEdge = max(image.extent.width, image.extent.height)
        guard longEdge > maxLongEdge else {
            return image
        }

        let scale = maxLongEdge / longEdge
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func previewCacheKey(
        for url: URL,
        adjustments: PhotoAdjustments,
        maxPixelSize: CGFloat,
        showClippingWarnings: Bool
    ) -> NSString {
        let adjustmentData = (try? JSONEncoder().encode(adjustments)) ?? Data()
        let adjustmentKey = adjustmentData.base64EncodedString()
        let namespace = showClippingWarnings ? "preview-clipping" : "preview"
        let baseKey = imageCacheKey(for: url, pixelSize: maxPixelSize, namespace: namespace)

        return "\(baseKey)|\(adjustmentKey)" as NSString
    }

    private func clippingWarningPreview(from image: NSImage) -> NSImage {
        guard
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let output = clippingWarningImage(from: cgImage)
        else {
            return image
        }

        return NSImage(cgImage: output, size: image.size)
    }

    private func clippingWarningImage(from cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let bitmapContext = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let maxChannel = max(red, green, blue)

            if maxChannel >= 250 {
                pixels[index] = 255
                pixels[index + 1] = 64
                pixels[index + 2] = 48
                pixels[index + 3] = 255
            } else if maxChannel <= 5 {
                pixels[index] = 48
                pixels[index + 1] = 112
                pixels[index + 2] = 255
                pixels[index + 3] = 255
            }
        }

        return bitmapContext.makeImage()
    }

    private func imageCacheKey(for url: URL, pixelSize: CGFloat, namespace: String) -> NSString {
        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modifiedAt = resourceValues?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let fileSize = resourceValues?.fileSize ?? 0
        let roundedPixelSize = Int(pixelSize.rounded())

        return "\(namespace)|\(url.path)|\(modifiedAt)|\(fileSize)|\(roundedPixelSize)" as NSString
    }

    private func imageCost(_ image: NSImage) -> Int {
        let width = max(1, Int(image.size.width.rounded(.up)))
        let height = max(1, Int(image.size.height.rounded(.up)))
        return width * height * 4
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

    private func straighten(_ image: CIImage, degrees: Double) -> CIImage {
        guard degrees != 0 else {
            return image
        }

        let radians = CGFloat(degrees * .pi / 180)
        let extent = image.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: radians)
            .translatedBy(x: -center.x, y: -center.y)

        return normalizeExtent(image.transformed(by: transform))
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

    private func flip(_ image: CIImage, horizontal: Bool, vertical: Bool) -> CIImage {
        guard horizontal || vertical else {
            return image
        }

        let extent = image.extent
        let transform = CGAffineTransform(translationX: extent.midX, y: extent.midY)
            .scaledBy(x: horizontal ? -1 : 1, y: vertical ? -1 : 1)
            .translatedBy(x: -extent.midX, y: -extent.midY)

        return normalizeExtent(image.transformed(by: transform))
    }

    private func normalizeExtent(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y))
    }

    private func applyColorMixer(_ mixer: ColorMixerAdjustments, to image: CIImage) -> CIImage {
        let dimension = 24
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)

        for blueIndex in 0..<dimension {
            for greenIndex in 0..<dimension {
                for redIndex in 0..<dimension {
                    let red = Double(redIndex) / Double(dimension - 1)
                    let green = Double(greenIndex) / Double(dimension - 1)
                    let blue = Double(blueIndex) / Double(dimension - 1)
                    let hsv = rgbToHSV(red: red, green: green, blue: blue)
                    let saturation = clipped(hsv.saturation * (1 + colorMixerAmount(for: hsv.hue, mixer: mixer)))
                    let rgb = hsvToRGB(hue: hsv.hue, saturation: saturation, value: hsv.value)

                    cube.append(Float(rgb.red))
                    cube.append(Float(rgb.green))
                    cube.append(Float(rgb.blue))
                    cube.append(1)
                }
            }
        }

        let data = cube.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        guard let filter = CIFilter(name: "CIColorCube") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    private func applyFaceSlim(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount > 0 else {
            return image
        }

        let faces = faceFeatures(in: image)
        guard !faces.isEmpty else {
            return image
        }

        return faces.reduce(image) { currentImage, face in
            guard let filter = CIFilter(name: "CIPinchDistortion") else {
                return currentImage
            }

            let bounds = face.bounds
            let center = CIVector(x: bounds.midX, y: bounds.midY)
            let radius = max(bounds.width, bounds.height) * (0.65 + amount * 0.35)

            filter.setValue(currentImage, forKey: kCIInputImageKey)
            filter.setValue(center, forKey: kCIInputCenterKey)
            filter.setValue(radius, forKey: kCIInputRadiusKey)
            filter.setValue(amount * 0.45, forKey: kCIInputScaleKey)
            return filter.outputImage?.cropped(to: currentImage.extent) ?? currentImage
        }
    }

    private func applyEyeEnlarge(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount > 0 else {
            return image
        }

        let faces = faceFeatures(in: image)
        guard !faces.isEmpty else {
            return image
        }

        return faces.reduce(image) { currentImage, face in
            var output = currentImage
            let eyeRadius = max(face.bounds.width, face.bounds.height) * (0.10 + amount * 0.05)

            if face.hasLeftEyePosition {
                output = applyEyeBump(to: output, center: face.leftEyePosition, radius: eyeRadius, amount: amount)
            }

            if face.hasRightEyePosition {
                output = applyEyeBump(to: output, center: face.rightEyePosition, radius: eyeRadius, amount: amount)
            }

            return output
        }
    }

    private func applyEyeBump(to image: CIImage, center: CGPoint, radius: CGFloat, amount: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIBumpDistortion") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: center.x, y: center.y), forKey: kCIInputCenterKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(amount * 0.35, forKey: kCIInputScaleKey)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private func applyBodySlim(_ amount: Double, to image: CIImage) -> CIImage {
        guard amount > 0, let filter = CIFilter(name: "CIPinchDistortion") else {
            return image
        }

        let extent = image.extent
        let center = CIVector(x: extent.midX, y: extent.midY - extent.height * 0.08)
        let radius = min(extent.width, extent.height) * (0.42 + amount * 0.18)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(center, forKey: kCIInputCenterKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(amount * 0.28, forKey: kCIInputScaleKey)
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    private func applyRadialExposure(_ adjustments: PhotoAdjustments, to image: CIImage) -> CIImage {
        guard adjustments.radialExposure != 0,
              let exposure = CIFilter(name: "CIExposureAdjust"),
              let gradient = CIFilter(name: "CIRadialGradient"),
              let blend = CIFilter(name: "CIBlendWithMask") else {
            return image
        }

        let extent = image.extent
        let shortEdge = min(extent.width, extent.height)
        let centerX = extent.minX + extent.width * clipped(adjustments.radialCenterX)
        let centerY = extent.minY + extent.height * clipped(adjustments.radialCenterY)
        let innerRadius = shortEdge * max(0.02, clipped(adjustments.radialRadius))
        let outerRadius = innerRadius + shortEdge * max(0.01, clipped(adjustments.radialFeather))

        exposure.setValue(image, forKey: kCIInputImageKey)
        exposure.setValue(adjustments.radialExposure, forKey: kCIInputEVKey)

        gradient.setValue(CIVector(x: centerX, y: centerY), forKey: kCIInputCenterKey)
        gradient.setValue(innerRadius, forKey: "inputRadius0")
        gradient.setValue(outerRadius, forKey: "inputRadius1")
        gradient.setValue(adjustments.radialInvert ? CIColor.black : CIColor.white, forKey: "inputColor0")
        gradient.setValue(adjustments.radialInvert ? CIColor.white : CIColor.black, forKey: "inputColor1")

        guard let adjusted = exposure.outputImage,
              let mask = gradient.outputImage?.cropped(to: extent) else {
            return image
        }

        blend.setValue(adjusted, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private func applyLinearExposure(_ adjustments: PhotoAdjustments, to image: CIImage) -> CIImage {
        guard adjustments.linearExposure != 0,
              let exposure = CIFilter(name: "CIExposureAdjust"),
              let gradient = CIFilter(name: "CILinearGradient"),
              let blend = CIFilter(name: "CIBlendWithMask") else {
            return image
        }

        let extent = image.extent
        let startY = extent.minY + extent.height * clipped(adjustments.linearStartY)
        let endY = extent.minY + extent.height * clipped(adjustments.linearEndY)

        exposure.setValue(image, forKey: kCIInputImageKey)
        exposure.setValue(adjustments.linearExposure, forKey: kCIInputEVKey)

        gradient.setValue(CIVector(x: extent.midX, y: startY), forKey: "inputPoint0")
        gradient.setValue(CIVector(x: extent.midX, y: endY), forKey: "inputPoint1")
        gradient.setValue(adjustments.linearInvert ? CIColor.black : CIColor.white, forKey: "inputColor0")
        gradient.setValue(adjustments.linearInvert ? CIColor.white : CIColor.black, forKey: "inputColor1")

        guard let adjusted = exposure.outputImage,
              let mask = gradient.outputImage?.cropped(to: extent) else {
            return image
        }

        blend.setValue(adjusted, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private func applySpotHeal(_ adjustments: PhotoAdjustments, to image: CIImage) -> CIImage {
        guard adjustments.spotHealAmount > 0,
              let gradient = CIFilter(name: "CIRadialGradient"),
              let blend = CIFilter(name: "CIBlendWithMask") else {
            return image
        }

        let extent = image.extent
        let shortEdge = min(extent.width, extent.height)
        let targetX = extent.minX + extent.width * clipped(adjustments.spotHealX)
        let targetY = extent.minY + extent.height * clipped(adjustments.spotHealY)
        let sourceX = targetX + extent.width * max(-1, min(1, adjustments.spotHealSourceOffsetX))
        let sourceY = targetY + extent.height * max(-1, min(1, adjustments.spotHealSourceOffsetY))
        let radius = shortEdge * max(0.01, clipped(adjustments.spotHealRadius))
        let outerRadius = radius + shortEdge * max(0.005, clipped(adjustments.spotHealFeather))
        let sourcePatch = image
            .clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: targetX - sourceX, y: targetY - sourceY))
            .cropped(to: extent)

        gradient.setValue(CIVector(x: targetX, y: targetY), forKey: kCIInputCenterKey)
        gradient.setValue(radius, forKey: "inputRadius0")
        gradient.setValue(outerRadius, forKey: "inputRadius1")
        gradient.setValue(CIColor(red: clipped(adjustments.spotHealAmount), green: clipped(adjustments.spotHealAmount), blue: clipped(adjustments.spotHealAmount)), forKey: "inputColor0")
        gradient.setValue(CIColor.black, forKey: "inputColor1")

        guard let mask = gradient.outputImage?.cropped(to: extent) else {
            return image
        }

        blend.setValue(sourcePatch, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask, forKey: kCIInputMaskImageKey)
        return blend.outputImage?.cropped(to: extent) ?? image
    }

    private func faceFeatures(in image: CIImage) -> [CIFaceFeature] {
        let detector = CIDetector(
            ofType: CIDetectorTypeFace,
            context: context,
            options: [CIDetectorAccuracy: CIDetectorAccuracyLow]
        )

        return detector?.features(in: image).compactMap { $0 as? CIFaceFeature } ?? []
    }

    private func colorMixerAmount(for hue: Double, mixer: ColorMixerAdjustments) -> Double {
        let controls: [(center: Double, amount: Double)] = [
            (0, mixer.red),
            (30, mixer.orange),
            (60, mixer.yellow),
            (120, mixer.green),
            (180, mixer.aqua),
            (240, mixer.blue),
            (280, mixer.purple),
            (320, mixer.magenta),
            (360, mixer.red)
        ]

        return controls.reduce(0) { result, control in
            let distance = abs(hue - control.center)
            let weight = max(0, 1 - distance / 35)
            return result + control.amount * weight
        }
    }

    private func rgbToHSV(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, value: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxValue == red {
            hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxValue == green {
            hue = 60 * ((blue - red) / delta + 2)
        } else {
            hue = 60 * ((red - green) / delta + 4)
        }

        let normalizedHue = hue < 0 ? hue + 360 : hue
        let saturation = maxValue == 0 ? 0 : delta / maxValue
        return (normalizedHue, saturation, maxValue)
    }

    private func hsvToRGB(hue: Double, saturation: Double, value: Double) -> (red: Double, green: Double, blue: Double) {
        let chroma = value * saturation
        let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = value - chroma

        let rgb: (Double, Double, Double)
        switch hue {
        case 0..<60:
            rgb = (chroma, x, 0)
        case 60..<120:
            rgb = (x, chroma, 0)
        case 120..<180:
            rgb = (0, chroma, x)
        case 180..<240:
            rgb = (0, x, chroma)
        case 240..<300:
            rgb = (x, 0, chroma)
        default:
            rgb = (chroma, 0, x)
        }

        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }

    private func clipped(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func isoValue(from value: Any?) -> Int? {
        if let ratings = value as? [Int] {
            return ratings.first
        }

        if let ratings = value as? [Double] {
            return ratings.first.map(Int.init)
        }

        return value as? Int
    }

    private func captureDate(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: value)
    }

    private func render(_ image: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: outputColorSpace) else {
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
