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
    @Published var libraryFilter: LibraryFilter = .all
    @Published var searchText = ""
    @Published var showOriginal = false {
        didSet {
            renderSelectedPreview()
        }
    }

    private var renderTask: Task<Void, Never>?
    private var copiedAdjustments: PhotoAdjustments?
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
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return filteredByFlag
        }

        return filteredByFlag.filter {
            $0.fileName.localizedCaseInsensitiveContains(query)
        }
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

    func updateSelectedAdjustments(_ update: (inout PhotoAdjustments) -> Void) {
        guard
            let selectedPhotoID,
            let index = photos.firstIndex(where: { $0.id == selectedPhotoID })
        else {
            return
        }

        update(&photos[index].adjustments)
        renderSelectedPreview()
        saveCatalog()
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

    func applyPreset(_ preset: PhotoPreset) {
        updateSelectedAdjustments { adjustments in
            let rotationTurns = adjustments.rotationTurns
            adjustments = preset.adjustments
            adjustments.rotationTurns = rotationTurns
        }
        statusMessage = "Applied \(preset.rawValue) preset."
    }

    func autoEnhanceSelected() {
        updateSelectedAdjustments { adjustments in
            adjustments.exposure += 0.15
            adjustments.contrast = max(adjustments.contrast, 1.12)
            adjustments.saturation = max(adjustments.saturation, 1.04)
            adjustments.vibrance = max(adjustments.vibrance, 0.24)
            adjustments.sharpness = max(adjustments.sharpness, 0.5)
        }
        statusMessage = "Applied auto enhance."
    }

    func rotateSelectedLeft() {
        updateSelectedAdjustments { adjustments in
            adjustments.rotationTurns -= 1
        }
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
                to: destination
            )
            statusMessage = "Exported \(destination.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
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

    private func renderSelectedPreview() {
        renderTask?.cancel()
        previewImage = nil

        guard let selectedPhoto else {
            isRenderingPreview = false
            return
        }

        isRenderingPreview = true
        let url = selectedPhoto.url
        let adjustments = showOriginal ? .neutral : selectedPhoto.adjustments

        renderTask = Task.detached(priority: .userInitiated) {
            let image = ImageProcessor.shared.preview(for: url, adjustments: adjustments)

            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }

                self.previewImage = image
                self.isRenderingPreview = false
            }
        }
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
