import SwiftUI

struct MainView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        NavigationSplitView {
            LibrarySidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
        } detail: {
            EditorView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    library.importPhotos()
                } label: {
                    Label("Open", systemImage: "folder")
                }

                Button {
                    library.undoAdjustment()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!library.canUndo)

                Button {
                    library.redoAdjustment()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(!library.canRedo)

                Button {
                    library.showOriginal.toggle()
                } label: {
                    Label("Before", systemImage: library.showOriginal ? "eye.slash" : "eye")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.rotateSelectedLeft()
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.rotateSelectedRight()
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.exportSelectedPhoto()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.exportPickedPhotos()
                } label: {
                    Label("Export Picked", systemImage: "tray.and.arrow.up")
                }
                .disabled(library.pickedPhotoCount == 0)
            }
        }
    }
}

struct LibrarySidebar: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    private let columns = [
        GridItem(.adaptive(minimum: 112, maximum: 150), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library")
                    .font(.headline)

                Spacer()

                Text("\(library.filteredPhotos.count)/\(library.photos.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Picker("Filter", selection: $library.libraryFilter) {
                ForEach(LibraryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            TextField("Search file names", text: $library.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Divider()

            if library.photos.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("Import local photos to start editing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if library.filteredPhotos.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Change the library filter to see more photos.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(library.filteredPhotos) { photo in
                            Button {
                                library.select(photo)
                            } label: {
                                PhotoGridCell(
                                    photo: photo,
                                    isSelected: photo.id == library.selectedPhotoID
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            Text(library.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }
}

struct PhotoGridCell: View {
    let photo: PhotoAsset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                if let thumbnail = photo.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
            .overlay(alignment: .topLeading) {
                if photo.metadata?.isRaw == true {
                    Text("RAW")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if photo.flag != .none {
                    Image(systemName: photo.flag == .picked ? "flag.fill" : "xmark.circle.fill")
                        .foregroundStyle(photo.flag == .picked ? .green : .red)
                        .padding(6)
                }
            }

            Text(photo.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            if photo.rating > 0 {
                RatingStars(rating: photo.rating)
                    .font(.caption2)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel(photo.fileName)
    }
}

struct EditorView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        HStack(spacing: 0) {
            PreviewPane()

            Divider()

            AdjustmentPanel()
                .frame(width: 300)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PreviewPane: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            if library.selectedPhoto == nil {
                ContentUnavailableView(
                    "Select a Photo",
                    systemImage: "photo",
                    description: Text("Imported photos will appear in the library.")
                )
            } else if library.isRenderingPreview {
                ProgressView()
                    .controlSize(.large)
            } else if let previewImage = library.previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(32)

                if library.showOriginal {
                    VStack {
                        HStack {
                            Text("Original")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())

                            Spacer()
                        }

                        Spacer()
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Preview Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Luma could not render this image.")
                )
            }
        }
    }
}

struct AdjustmentPanel: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Edit")
                    .font(.headline)

                if let selectedPhoto = library.selectedPhoto {
                    Text(selectedPhoto.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No photo selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let histogramBins = library.selectedPhoto?.histogramBins {
                HistogramView(bins: histogramBins)
                    .frame(height: 86)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Rating")
                        .font(.headline)

                    Spacer()

                    Button("Clear") {
                        library.setSelectedRating(0)
                    }
                    .disabled(library.selectedPhoto == nil || library.selectedPhoto?.rating == 0)
                }

                RatingControl(
                    rating: library.selectedPhoto?.rating ?? 0,
                    setRating: library.setSelectedRating
                )
                .disabled(library.selectedPhoto == nil)

                HStack {
                    Button {
                        library.setSelectedFlag(.picked)
                    } label: {
                        Label("Pick", systemImage: "flag.fill")
                    }

                    Button {
                        library.setSelectedFlag(.rejected)
                    } label: {
                        Label("Reject", systemImage: "xmark.circle")
                    }

                    Button {
                        library.setSelectedFlag(.none)
                    } label: {
                        Label("Clear", systemImage: "flag.slash")
                    }
                }
                .disabled(library.selectedPhoto == nil)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Presets")
                    .font(.headline)

                HStack {
                    Menu {
                        ForEach(PhotoPreset.allCases) { preset in
                            Button(preset.rawValue) {
                                library.applyPreset(preset)
                            }
                        }
                    } label: {
                        Label("Apply Preset", systemImage: "slider.horizontal.3")
                    }
                    .disabled(library.selectedPhoto == nil)

                    Button {
                        library.autoEnhanceSelected()
                    } label: {
                        Label("Auto", systemImage: "wand.and.stars")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Adjustments")
                    .font(.headline)

                HStack {
                    Button {
                        library.copySelectedAdjustments()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(library.selectedPhoto == nil)

                    Button {
                        library.pasteAdjustmentsToSelected()
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Crop")
                    .font(.headline)

                Picker("Aspect", selection: adjustmentBinding(\.cropAspect)) {
                    ForEach(CropAspect.allCases) { aspect in
                        Text(aspect.rawValue).tag(aspect)
                    }
                }
                .pickerStyle(.menu)
                .disabled(library.selectedPhoto == nil)
            }

            AdjustmentSlider(
                title: "Exposure",
                value: adjustmentBinding(\.exposure),
                range: -3...3,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Highlights",
                value: adjustmentBinding(\.highlights),
                range: -1...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Shadows",
                value: adjustmentBinding(\.shadows),
                range: -1...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Contrast",
                value: adjustmentBinding(\.contrast),
                range: 0.5...1.8,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Saturation",
                value: adjustmentBinding(\.saturation),
                range: 0...2,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Warmth",
                value: adjustmentBinding(\.warmth),
                range: -1500...1500,
                format: "%.0f"
            )

            AdjustmentSlider(
                title: "Tint",
                value: adjustmentBinding(\.tint),
                range: -150...150,
                format: "%.0f"
            )

            AdjustmentSlider(
                title: "Vibrance",
                value: adjustmentBinding(\.vibrance),
                range: -1...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Clarity",
                value: adjustmentBinding(\.clarity),
                range: 0...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Dehaze",
                value: adjustmentBinding(\.dehaze),
                range: -1...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Noise Reduction",
                value: adjustmentBinding(\.noiseReduction),
                range: 0...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Sharpness",
                value: adjustmentBinding(\.sharpness),
                range: 0...2,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Vignette",
                value: adjustmentBinding(\.vignette),
                range: 0...1,
                format: "%.2f"
            )

            if let metadata = library.selectedPhoto?.metadata {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Info")
                        .font(.headline)

                    InfoRow(label: "Dimensions", value: metadata.dimensionsText)
                    InfoRow(label: "Resolution", value: metadata.megapixelsText)
                    InfoRow(label: "File Size", value: metadata.fileSizeText)
                    InfoRow(label: "Format", value: metadata.formatText)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Export")
                    .font(.headline)

                AdjustmentSlider(
                    title: "JPEG Quality",
                    value: $library.exportQuality,
                    range: 0.5...1,
                    format: "%.2f"
                )
            }

            Button {
                library.resetSelectedAdjustments()
            } label: {
                Label("Reset Adjustments", systemImage: "arrow.counterclockwise")
            }
            .disabled(library.selectedPhoto == nil)

            Button(role: .destructive) {
                library.removeSelectedPhoto()
            } label: {
                Label("Remove From Library", systemImage: "minus.circle")
            }
            .disabled(library.selectedPhoto == nil)

            Spacer()
        }
        .padding(18)
        }
    }

    private func adjustmentBinding(_ keyPath: WritableKeyPath<PhotoAdjustments, Double>) -> Binding<Double> {
        Binding {
            library.selectedAdjustments[keyPath: keyPath]
        } set: { value in
            library.updateSelectedAdjustments { adjustments in
                adjustments[keyPath: keyPath] = value
            }
        }
    }

    private func adjustmentBinding(_ keyPath: WritableKeyPath<PhotoAdjustments, CropAspect>) -> Binding<CropAspect> {
        Binding {
            library.selectedAdjustments[keyPath: keyPath]
        } set: { value in
            library.updateSelectedAdjustments { adjustments in
                adjustments[keyPath: keyPath] = value
            }
        }
    }
}

struct HistogramView: View {
    let bins: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Histogram")
                .font(.headline)

            GeometryReader { geometry in
                let barWidth = max(1, geometry.size.width / CGFloat(max(1, bins.count)))

                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(bins.enumerated()), id: \.offset) { _, value in
                        Rectangle()
                            .fill(.secondary)
                            .frame(width: barWidth, height: max(2, geometry.size.height * value))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct RatingControl: View {
    let rating: Int
    let setRating: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    setRating(value)
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .foregroundStyle(value <= rating ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.title3)
    }
}

struct RatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
            }
        }
        .foregroundStyle(.yellow)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}
