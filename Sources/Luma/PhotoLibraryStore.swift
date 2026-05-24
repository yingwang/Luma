import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var photos: [PhotoAsset] = []
    @Published var selectedPhotoID: PhotoAsset.ID?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var isRenderingPreview = false
    @Published var statusMessage = "Import photos to begin."
    @Published var libraryFilter: LibraryFilter = .all {
        didSet {
            ensureSelectedPhotoIsVisible()
        }
    }
    @Published var librarySort: LibrarySort = .fileName
    @Published var minimumRating = 0 {
        didSet {
            ensureSelectedPhotoIsVisible()
        }
    }
    @Published var searchText = "" {
        didSet {
            ensureSelectedPhotoIsVisible()
        }
    }
    @Published var hideRejected = false {
        didSet {
            ensureSelectedPhotoIsVisible()
        }
    }
    @Published var thumbnailSize = 124.0
    @Published var exportQuality = 0.92
    @Published var exportLongEdge: Double = 0
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var showOriginal = false {
        didSet {
            if showOriginal {
                compareSideBySide = false
            }
            renderSelectedPreview()
        }
    }
    @Published var compareSideBySide = false {
        didSet {
            renderSelectedPreview()
        }
    }
    @Published private(set) var originalPreviewImage: NSImage?

    private var renderTask: Task<Void, Never>?
    private var copiedAdjustments: PhotoAdjustments?
    private var undoStack: [AdjustmentHistoryEntry] = []
    private var redoStack: [AdjustmentHistoryEntry] = []
    private let catalogURL = PhotoLibraryStore.defaultCatalogURL

    init() {
        loadCatalog()
    }

    var selectedPhoto: PhotoAsset? {
        guard let selectedPhotoID else {
            return nil
        }

        return photos.first { $0.id == selectedPhotoID }
    }

    var selectedAdjustments: PhotoAdjustments {
        selectedPhoto?.adjustments ?? .neutral
    }

    var pickedPhotoCount: Int {
        photos.filter { $0.flag == .picked }.count
    }

    var hasActiveLibraryFilters: Bool {
        libraryFilter != .all ||
            minimumRating > 0 ||
            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            hideRejected
    }

    var filteredPhotos: [PhotoAsset] {
        let filteredByFlag = switch libraryFilter {
        case .all:
            photos
        case .picked:
            photos.filter { $0.flag == .picked }
        case .rejected:
            photos.filter { $0.flag == .rejected }
        case .rated:
            photos.filter { $0.rating > 0 }
        case .unrated:
            photos.filter { $0.rating == 0 }
        case .unflagged:
            photos.filter { $0.flag == .none }
        case .edited:
            photos.filter { $0.adjustments != .neutral }
        case .unedited:
            photos.filter { $0.adjustments == .neutral }
        }

        let filteredByHiddenRejected = hideRejected && libraryFilter != .rejected
            ? filteredByFlag.filter { $0.flag != .rejected }
            : filteredByFlag

        let filteredByRating = minimumRating > 0
            ? filteredByHiddenRejected.filter { $0.rating >= minimumRating }
            : filteredByHiddenRejected

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredBySearch = if query.isEmpty {
            filteredByRating
        } else {
            filteredByRating.filter {
                $0.fileName.localizedCaseInsensitiveContains(query)
            }
        }

        return sortedPhotos(filteredBySearch)
    }

    func clearLibraryFilters() {
        libraryFilter = .all
        minimumRating = 0
        searchText = ""
        hideRejected = false
        statusMessage = "Cleared library filters."
        ensureSelectedPhotoIsVisible()
    }

    func importPhotos() {
        let panel = NSOpenPanel()
        panel.title = "Open Photos"
        panel.message = "Choose image files or folders containing images."
        panel.prompt = "Open"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else {
            return
        }

        addPhotos(panel.urls)
    }

    func importDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        let fileURLType = UTType.fileURL.identifier
        let acceptedProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(fileURLType) }

        for provider in acceptedProviders {
            provider.loadItem(forTypeIdentifier: fileURLType, options: nil) { item, _ in
                let url: URL?

                if let itemURL = item as? URL {
                    url = itemURL
                } else if let itemData = item as? Data {
                    url = URL(dataRepresentation: itemData, relativeTo: nil)
                } else {
                    url = nil
                }

                guard let url else {
                    return
                }

                Task { @MainActor in
                    self.addPhotos([url])
                }
            }
        }

        return !acceptedProviders.isEmpty
    }

    func addPhotos(_ urls: [URL]) {
        let imageURLs = expandedImageURLs(from: urls)
        let existingURLs = Set(photos.map(\.url))
        let newURLs = imageURLs.filter { !existingURLs.contains($0) }

        guard !newURLs.isEmpty else {
            statusMessage = "No new readable images were found."
            return
        }

        let imported = newURLs.map {
            PhotoAsset(
                url: $0,
                metadata: ImageProcessor.shared.metadata(for: $0),
                histogramBins: ImageProcessor.shared.luminanceHistogram(for: $0)
            )
        }
        photos.append(contentsOf: imported)
        selectedPhotoID = imported.first?.id
        showOriginal = false
        statusMessage = "Imported \(newURLs.count) photo\(newURLs.count == 1 ? "" : "s")."

        generateThumbnails(for: imported)
        renderSelectedPreview()
        saveCatalog()
    }

    private func expandedImageURLs(from urls: [URL]) -> [URL] {
        var results: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if exists, isDirectory.boolValue {
                results.append(contentsOf: imageURLs(in: url))
            } else if ImageProcessor.shared.canReadImage(at: url) {
                results.append(url)
            }
        }

        return Array(NSOrderedSet(array: results)) as? [URL] ?? results
    }

    private func imageURLs(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey])
                return resourceValues?.isRegularFile == true && ImageProcessor.shared.canReadImage(at: url)
            }
    }

    func select(_ photo: PhotoAsset) {
        selectedPhotoID = photo.id
        statusMessage = "Selected \(photo.fileName)."
        renderSelectedPreview()
    }

    func selectPreviousPhoto() {
        selectAdjacentPhoto(offset: -1)
    }

    func selectNextPhoto() {
        selectAdjacentPhoto(offset: 1)
    }

    func selectFirstVisiblePhoto() {
        guard let firstPhoto = filteredPhotos.first else {
            return
        }

        select(firstPhoto)
    }

    func selectLastVisiblePhoto() {
        guard let lastPhoto = filteredPhotos.last else {
            return
        }

        select(lastPhoto)
    }

    func toggleCompareSideBySide() {
        if showOriginal {
            showOriginal = false
        }
        compareSideBySide.toggle()
    }

    func updateSelectedAdjustments(_ update: (inout PhotoAdjustments) -> Void) {
        guard
            let selectedPhotoID,
            let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return
        }

        let before = photos[index].adjustments
        update(&photos[index].adjustments)
        let after = photos[index].adjustments

        if before != after {
            undoStack.append(AdjustmentHistoryEntry(photoID: selectedPhotoID, before: before, after: after))
            redoStack.removeAll()
            updateHistoryState()
        }

        renderSelectedPreview()
        saveCatalog()
    }

    func undoAdjustment() {
        guard let entry = undoStack.popLast() else {
            return
        }

        applyAdjustment(entry.before, to: entry.photoID)
        redoStack.append(entry)
        updateHistoryState()
        statusMessage = "Undid adjustment."
    }

    func redoAdjustment() {
        guard let entry = redoStack.popLast() else {
            return
        }

        applyAdjustment(entry.after, to: entry.photoID)
        undoStack.append(entry)
        updateHistoryState()
        statusMessage = "Redid adjustment."
    }

    func setSelectedRating(_ rating: Int) {
        guard
            let selectedPhotoID,
            let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return
        }

        photos[index].rating = min(5, max(0, rating))
        statusMessage = "Rated \(photos[index].fileName) \(photos[index].rating) star\(photos[index].rating == 1 ? "" : "s")."
        saveCatalog()
        ensureSelectedPhotoIsVisible()
    }

    func setSelectedFlag(_ flag: PhotoFlag) {
        guard
            let selectedPhotoID,
            let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return
        }

        photos[index].flag = flag
        statusMessage = "\(flag.rawValue) \(photos[index].fileName)."
        saveCatalog()
        ensureSelectedPhotoIsVisible()
    }

    func removeSelectedPhoto() {
        guard
            let selectedPhotoID,
            let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return
        }

        let removed = photos.remove(at: index)
        self.selectedPhotoID = filteredPhotos.first?.id ?? photos.first?.id
        statusMessage = "Removed \(removed.fileName) from the library."
        saveCatalog()
        renderSelectedPreview()
    }

    func copySelectedAdjustments() {
        guard let selectedPhoto else {
            return
        }

        copiedAdjustments = selectedPhoto.adjustments
        statusMessage = "Copied adjustments from \(selectedPhoto.fileName)."
    }

    func pasteAdjustmentsToSelected() {
        guard let copiedAdjustments else {
            statusMessage = "No copied adjustments."
            return
        }

        updateSelectedAdjustments { adjustments in
            let rotationTurns = adjustments.rotationTurns
            adjustments = copiedAdjustments
            adjustments.rotationTurns = rotationTurns
        }
        statusMessage = "Pasted adjustments."
    }

    func syncSelectedAdjustmentsToPicked() {
        guard let selectedPhoto else {
            return
        }

        let pickedIndexes = photos.indices.filter {
            photos[$0].flag == .picked && photos[$0].id != selectedPhoto.id
        }

        guard !pickedIndexes.isEmpty else {
            statusMessage = "No other picked photos to sync."
            return
        }

        for index in pickedIndexes {
            var syncedAdjustments = selectedPhoto.adjustments
            syncedAdjustments.rotationTurns = photos[index].adjustments.rotationTurns
            photos[index].adjustments = syncedAdjustments
        }

        saveCatalog()
        statusMessage = "Synced adjustments to \(pickedIndexes.count) picked photo\(pickedIndexes.count == 1 ? "" : "s")."
    }

    func applyPreset(_ preset: PhotoPreset) {
        updateSelectedAdjustments { adjustments in
            let rotationTurns = adjustments.rotationTurns
            adjustments = preset.adjustments
            adjustments.rotationTurns = rotationTurns
        }
        statusMessage = "Applied \(preset.rawValue) preset."
    }

    func applyPresetToPicked(_ preset: PhotoPreset) {
        let pickedIndexes = photos.indices.filter {
            photos[$0].flag == .picked
        }

        guard !pickedIndexes.isEmpty else {
            statusMessage = "No picked photos to update."
            return
        }

        for index in pickedIndexes {
            let rotationTurns = photos[index].adjustments.rotationTurns
            photos[index].adjustments = preset.adjustments
            photos[index].adjustments.rotationTurns = rotationTurns
        }

        saveCatalog()
        renderSelectedPreview()
        statusMessage = "Applied \(preset.rawValue) preset to \(pickedIndexes.count) picked photo\(pickedIndexes.count == 1 ? "" : "s")."
    }

    func autoEnhanceSelected() {
        updateSelectedAdjustments { adjustments in
            adjustments.exposure += 0.15
            adjustments.highlights = min(adjustments.highlights, -0.15)
            adjustments.shadows = max(adjustments.shadows, 0.2)
            adjustments.contrast = max(adjustments.contrast, 1.12)
            adjustments.saturation = max(adjustments.saturation, 1.04)
            adjustments.vibrance = max(adjustments.vibrance, 0.24)
            adjustments.clarity = max(adjustments.clarity, 0.15)
            adjustments.sharpness = max(adjustments.sharpness, 0.5)
        }
        statusMessage = "Applied auto enhance."
    }

    func autoBeautySelected() {
        updateSelectedAdjustments { adjustments in
            adjustments.beautySmooth = max(adjustments.beautySmooth, 0.28)
            adjustments.beautyWrinkle = max(adjustments.beautyWrinkle, 0.16)
            adjustments.beautyBlemish = max(adjustments.beautyBlemish, 0.18)
            adjustments.beautyWhiten = max(adjustments.beautyWhiten, 0.18)
            adjustments.beautyRosy = max(adjustments.beautyRosy, 0.12)
            adjustments.beautyBrighten = max(adjustments.beautyBrighten, 0.16)
            adjustments.beautyGlow = max(adjustments.beautyGlow, 0.10)
            adjustments.beautySoften = max(adjustments.beautySoften, 0.12)
            adjustments.beautyDetail = max(adjustments.beautyDetail, 0.08)
            adjustments.eyeEnlarge = max(adjustments.eyeEnlarge, 0.10)
            adjustments.faceSlim = max(adjustments.faceSlim, 0.08)
        }
        statusMessage = "Applied auto beauty."
    }

    func rotateSelectedLeft() {
        updateSelectedAdjustments { adjustments in
            adjustments.rotationTurns -= 1
        }
    }

    func setSelectedCropAspect(_ cropAspect: CropAspect) {
        updateSelectedAdjustments { adjustments in
            adjustments.cropAspect = cropAspect
        }
        statusMessage = "Set crop to \(cropAspect.rawValue)."
    }

    func rotateSelectedRight() {
        updateSelectedAdjustments { adjustments in
            adjustments.rotationTurns += 1
        }
    }

    func resetSelectedAdjustments() {
        updateSelectedAdjustments { adjustments in
            adjustments = .neutral
        }
        statusMessage = "Reset selected photo adjustments."
    }

    func resetPickedAdjustments() {
        let pickedIndexes = photos.indices.filter {
            photos[$0].flag == .picked
        }

        guard !pickedIndexes.isEmpty else {
            statusMessage = "No picked photos to reset."
            return
        }

        for index in pickedIndexes {
            let rotationTurns = photos[index].adjustments.rotationTurns
            photos[index].adjustments = .neutral
            photos[index].adjustments.rotationTurns = rotationTurns
        }

        saveCatalog()
        renderSelectedPreview()
        statusMessage = "Reset adjustments on \(pickedIndexes.count) picked photo\(pickedIndexes.count == 1 ? "" : "s")."
    }

    func clearImageCaches() {
        ImageProcessor.shared.clearImageCaches()
        generateThumbnails(for: photos)
        renderSelectedPreview()
        statusMessage = "Cleared image caches."
    }

    func applyExportPreset(_ preset: ExportPreset) {
        exportQuality = preset.jpegQuality
        exportLongEdge = preset.longEdge
        statusMessage = "Applied \(preset.rawValue) export preset."
    }

    func exportSelectedPhoto() {
        guard let selectedPhoto else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export JPEG"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.jpeg]
        panel.nameFieldStringValue = selectedPhoto.url.deletingPathExtension().lastPathComponent + "-luma.jpg"

        guard panel.runModal() == .OK, let destination = panel.url else {
            return
        }

        do {
            try ImageProcessor.shared.exportJPEG(
                from: selectedPhoto.url,
                adjustments: selectedPhoto.adjustments,
                to: destination,
                quality: exportQuality,
                maxLongEdge: exportMaxLongEdge
            )
            statusMessage = "Exported \(destination.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func exportPickedPhotos() {
        let pickedPhotos = photos.filter { $0.flag == .picked }
        guard !pickedPhotos.isEmpty else {
            statusMessage = "No picked photos to export."
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Export Picked Photos"
        panel.message = "Choose a folder for exported JPEG files."
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        var exportedCount = 0

        for photo in pickedPhotos {
            let destination = uniqueExportURL(for: photo, in: folderURL)

            do {
                try ImageProcessor.shared.exportJPEG(
                    from: photo.url,
                    adjustments: photo.adjustments,
                    to: destination,
                    quality: exportQuality,
                    maxLongEdge: exportMaxLongEdge
                )
                exportedCount += 1
            } catch {
                statusMessage = "Could not export \(photo.fileName): \(error.localizedDescription)"
                return
            }
        }

        statusMessage = "Exported \(exportedCount) picked photo\(exportedCount == 1 ? "" : "s")."
    }

    private func generateThumbnails(for imported: [PhotoAsset]) {
        for photo in imported {
            Task.detached(priority: .utility) {
                let thumbnail = ImageProcessor.shared.thumbnail(for: photo.url)

                await MainActor.run {
                    guard let index = self.photos.firstIndex(where: { $0.id == photo.id }) else {
                        return
                    }

                    self.photos[index].thumbnail = thumbnail
                }
            }
        }
    }

    private func uniqueExportURL(for photo: PhotoAsset, in folderURL: URL) -> URL {
        let baseName = photo.url.deletingPathExtension().lastPathComponent + "-luma"
        var destination = folderURL.appendingPathComponent(baseName).appendingPathExtension("jpg")
        var suffix = 2

        while FileManager.default.fileExists(atPath: destination.path) {
            destination = folderURL.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("jpg")
            suffix += 1
        }

        return destination
    }

    private func sortedPhotos(_ photos: [PhotoAsset]) -> [PhotoAsset] {
        switch librarySort {
        case .fileName:
            photos.sorted {
                $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        case .captureDate:
            photos.sorted {
                ($0.metadata?.captureDate ?? .distantPast) > ($1.metadata?.captureDate ?? .distantPast)
            }
        case .rating:
            photos.sorted {
                if $0.rating == $1.rating {
                    return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
                }

                return $0.rating > $1.rating
            }
        case .flag:
            photos.sorted {
                if $0.flag == $1.flag {
                    return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
                }

                return flagRank($0.flag) > flagRank($1.flag)
            }
        }
    }

    private func selectAdjacentPhoto(offset: Int) {
        let visiblePhotos = filteredPhotos
        guard !visiblePhotos.isEmpty else {
            return
        }

        guard
            let selectedPhotoID,
            let currentIndex = visiblePhotos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            select(visiblePhotos[0])
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), visiblePhotos.count - 1)
        guard nextIndex != currentIndex else {
            return
        }

        select(visiblePhotos[nextIndex])
    }

    private func ensureSelectedPhotoIsVisible() {
        let visiblePhotos = filteredPhotos

        guard
            let selectedPhotoID,
            visiblePhotos.contains(where: { $0.id == selectedPhotoID })
        else {
            self.selectedPhotoID = visiblePhotos.first?.id
            renderSelectedPreview()
            return
        }
    }

    private func flagRank(_ flag: PhotoFlag) -> Int {
        switch flag {
        case .picked:
            2
        case .none:
            1
        case .rejected:
            0
        }
    }

    private var exportMaxLongEdge: CGFloat? {
        exportLongEdge > 0 ? CGFloat(exportLongEdge) : nil
    }

    private func renderSelectedPreview() {
        renderTask?.cancel()
        previewImage = nil
        originalPreviewImage = nil

        guard let selectedPhoto else {
            isRenderingPreview = false
            return
        }

        isRenderingPreview = true
        let url = selectedPhoto.url
        let adjustments = selectedPhoto.adjustments
        let renderOriginal = showOriginal || compareSideBySide
        let renderComparison = compareSideBySide

        renderTask = Task.detached(priority: .userInitiated) {
            let image = ImageProcessor.shared.preview(
                for: url,
                adjustments: renderOriginal && !renderComparison ? .neutral : adjustments
            )
            let originalImage = renderComparison
                ? ImageProcessor.shared.preview(for: url, adjustments: .neutral)
                : nil

            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }

                self.previewImage = image
                self.originalPreviewImage = originalImage
                self.isRenderingPreview = false
            }
        }
    }

    private func applyAdjustment(_ adjustment: PhotoAdjustments, to photoID: PhotoAsset.ID) {
        guard let index = photos.firstIndex(where: { $0.id == photoID }) else {
            return
        }

        selectedPhotoID = photoID
        photos[index].adjustments = adjustment
        renderSelectedPreview()
        saveCatalog()
    }

    private func updateHistoryState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private static var defaultCatalogURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL.appendingPathComponent("Luma", isDirectory: true).appendingPathComponent("catalog.json")
    }

    private func loadCatalog() {
        guard
            let data = try? Data(contentsOf: catalogURL),
            let catalog = try? JSONDecoder().decode(CatalogFile.self, from: data)
        else {
            return
        }

        let loadedPhotos: [PhotoAsset] = catalog.entries.compactMap { entry -> PhotoAsset? in
            let url = URL(fileURLWithPath: entry.path)
            guard FileManager.default.fileExists(atPath: url.path), ImageProcessor.shared.canReadImage(at: url) else {
                return nil
            }

            var asset = PhotoAsset(
                id: entry.id,
                url: url,
                metadata: ImageProcessor.shared.metadata(for: url),
                histogramBins: ImageProcessor.shared.luminanceHistogram(for: url)
            )
            asset.adjustments = entry.adjustments
            asset.rating = entry.rating
            asset.flag = entry.flag
            return asset
        }

        photos = loadedPhotos
        selectedPhotoID = loadedPhotos.first?.id
        statusMessage = loadedPhotos.isEmpty ? "Import photos to begin." : "Loaded \(loadedPhotos.count) photo\(loadedPhotos.count == 1 ? "" : "s")."
        generateThumbnails(for: loadedPhotos)
        renderSelectedPreview()
    }

    private func saveCatalog() {
        do {
            try FileManager.default.createDirectory(
                at: catalogURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let catalog = CatalogFile(entries: photos.map {
                CatalogEntry(
                    id: $0.id,
                    path: $0.url.path,
                    adjustments: $0.adjustments,
                    rating: $0.rating,
                    flag: $0.flag
                )
            })
            let data = try JSONEncoder().encode(catalog)
            try data.write(to: catalogURL, options: .atomic)
        } catch {
            statusMessage = "Could not save catalog: \(error.localizedDescription)"
        }
    }
}
