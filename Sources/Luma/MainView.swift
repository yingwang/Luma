import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        NavigationSplitView {
            LibrarySidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
        } detail: {
            EditorView()
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            library.importDroppedItems(providers)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    library.importPhotos()
                } label: {
                    Label("Open", systemImage: "folder")
                }

                Button {
                    library.revealSelectedPhotoInFinder()
                } label: {
                    Label("Reveal", systemImage: "arrow.up.forward.app")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.duplicateSelectedPhoto()
                } label: {
                    Label("Virtual Copy", systemImage: "plus.square.on.square")
                }
                .disabled(library.selectedPhoto == nil)

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
                    library.selectPreviousPhoto()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(library.filteredPhotos.isEmpty)

                Button {
                    library.selectNextPhoto()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(library.filteredPhotos.isEmpty)

                Button {
                    library.showOriginal.toggle()
                } label: {
                    Label("Before", systemImage: library.showOriginal ? "eye.slash" : "eye")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.toggleCompareSideBySide()
                } label: {
                    Label("Compare", systemImage: "rectangle.split.2x1")
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.showClippingWarnings.toggle()
                } label: {
                    Label("Clipping", systemImage: library.showClippingWarnings ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
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

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: CGFloat(library.thumbnailSize), maximum: CGFloat(library.thumbnailSize + 42)),
                spacing: 12
            )
        ]
    }

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

            HStack {
                Text("Filter")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Filter", selection: $library.libraryFilter) {
                    ForEach(LibraryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Picker("Sort", selection: $library.librarySort) {
                ForEach(LibrarySort.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Toggle("Hide rejected", isOn: $library.hideRejected)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            HStack {
                Text("Min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                RatingControl(
                    rating: library.minimumRating,
                    setRating: { library.minimumRating = $0 }
                )
                .font(.caption)

                Button("Clear") {
                    library.minimumRating = 0
                }
                .font(.caption)
                .disabled(library.minimumRating == 0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Button {
                library.clearLibraryFilters()
            } label: {
                Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(!library.hasActiveLibraryFilters)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            HStack {
                Text("Size")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(value: $library.thumbnailSize, in: 88...180, step: 4)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                TextField("Search file names", text: $library.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    library.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(library.searchText.isEmpty ? .tertiary : .secondary)
                .help("Clear search")
                .disabled(library.searchText.isEmpty)
            }
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
            .overlay(alignment: .bottomLeading) {
                if photo.colorLabel != .none {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(photo.colorLabel.displayColor)
                        .frame(width: 34, height: 5)
                        .padding(6)
                }
            }

            Text(photo.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            RatingStars(rating: photo.rating)
                .font(.caption2)
                .frame(height: 12, alignment: .leading)
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
    @State private var zoomScale = 0.0

    private var canShowZoomControls: Bool {
        library.previewImage != nil || library.originalPreviewImage != nil
    }

    private var hasDisplayableContent: Bool {
        if library.compareSideBySide {
            return library.originalPreviewImage != nil && library.previewImage != nil
        }

        return library.previewImage != nil
    }

    private var zoomLabel: String {
        zoomScale == 0 ? "Fit" : "\(Int((zoomScale * 100).rounded()))%"
    }

    var body: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)

            if library.selectedPhoto == nil {
                ContentUnavailableView(
                    "Open Photos",
                    systemImage: "photo",
                    description: Text("Click here or drag photos into the workspace.")
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    library.importPhotos()
                }
            } else if library.compareSideBySide,
                      let originalPreviewImage = library.originalPreviewImage,
                      let previewImage = library.previewImage {
                HStack(spacing: 0) {
                    CompareImagePane(label: "Original", image: originalPreviewImage, zoomScale: zoomScale)

                    Divider()

                    CompareImagePane(label: "Edited", image: previewImage, zoomScale: zoomScale)
                }
            } else if !library.compareSideBySide, let previewImage = library.previewImage {
                PreviewImagePane(label: library.showOriginal ? "Original" : nil, image: previewImage, zoomScale: zoomScale)
            } else if library.isRenderingPreview {
                ProgressView()
                    .controlSize(.large)
            } else {
                ContentUnavailableView(
                    "Preview Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Luma could not render this image.")
                )
            }

            if library.isRenderingPreview, hasDisplayableContent {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(20)
            }
        }
        .overlay(alignment: .bottom) {
            if canShowZoomControls {
                HStack(spacing: 8) {
                    Button {
                        zoomScale = 0
                    } label: {
                        Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    }

                    Button {
                        zoomScale = 1
                    } label: {
                        Label("100%", systemImage: "1.magnifyingglass")
                    }

                    Divider()
                        .frame(height: 18)

                    Button {
                        zoomScale = zoomScale == 0 ? 0.75 : max(0.25, zoomScale / 1.25)
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }

                    Text(zoomLabel)
                        .font(.caption.monospacedDigit())
                        .frame(width: 48)

                    Button {
                        zoomScale = zoomScale == 0 ? 1.25 : min(4, zoomScale * 1.25)
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 18)
            }
        }
        .onChange(of: library.selectedPhotoID) { _, _ in
            zoomScale = 0
        }
    }
}

struct PreviewImagePane: View {
    let label: String?
    let image: NSImage
    let zoomScale: Double

    var body: some View {
        ZStack {
            if zoomScale == 0 {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(32)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: max(1, image.size.width * zoomScale),
                            height: max(1, image.size.height * zoomScale)
                        )
                        .padding(32)
                }
            }

            if let label {
                VStack {
                    HStack {
                        Text(label)
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
        }
    }
}

struct CompareImagePane: View {
    let label: String
    let image: NSImage
    let zoomScale: Double

    var body: some View {
        PreviewImagePane(label: label, image: image, zoomScale: zoomScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AdjustmentPanel: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var isLocalExpanded = false
    @State private var isLinearExpanded = false
    @State private var isHealExpanded = false
    @State private var isBeautyExpanded = false
    @State private var isColorMixerExpanded = false
    @State private var isInfoExpanded = false
    @State private var isExportExpanded = true

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
                HistogramView(
                    luminanceBins: histogramBins,
                    rgbBins: library.selectedPhoto?.rgbHistogramBins
                )
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Label")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(PhotoColorLabel.allCases) { colorLabel in
                            ColorLabelButton(
                                colorLabel: colorLabel,
                                isSelected: library.selectedPhoto?.colorLabel == colorLabel
                            ) {
                                library.setSelectedColorLabel(colorLabel)
                            }
                        }
                    }
                    .disabled(library.selectedPhoto == nil)
                }

                Button {
                    library.clearSelectedMarks()
                } label: {
                    Label("Clear Marks", systemImage: "tag.slash")
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

                    Button {
                        library.applyBlackAndWhiteSelected()
                    } label: {
                        Label("B&W", systemImage: "circle.lefthalf.filled")
                    }
                    .disabled(library.selectedPhoto == nil)
                }

                Menu {
                    ForEach(PhotoPreset.allCases) { preset in
                        Button(preset.rawValue) {
                            library.applyPresetToPicked(preset)
                        }
                    }
                } label: {
                    Label("Apply to Picked", systemImage: "square.stack.3d.up")
                }
                .disabled(library.pickedPhotoCount == 0)
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

                Button {
                    library.syncSelectedAdjustmentsToPicked()
                } label: {
                    Label("Sync to Picked", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(library.selectedPhoto == nil || library.pickedPhotoCount <= 1)

                Button {
                    library.resetPickedAdjustments()
                } label: {
                    Label("Reset Picked", systemImage: "arrow.counterclockwise.circle")
                }
                .disabled(library.pickedPhotoCount == 0)
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

                AdjustmentSlider(
                    title: "Straighten",
                    value: adjustmentBinding(\.straighten),
                    range: -45...45,
                    format: "%.1f"
                )

                HStack {
                    Button {
                        library.flipSelectedHorizontal()
                    } label: {
                        Label("Flip H", systemImage: "arrow.left.and.right")
                    }

                    Button {
                        library.flipSelectedVertical()
                    } label: {
                        Label("Flip V", systemImage: "arrow.up.and.down")
                    }
                }
                .disabled(library.selectedPhoto == nil)

                Button {
                    library.resetSelectedCropTransform()
                } label: {
                    Label("Reset Crop", systemImage: "crop.rotate")
                }
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
                title: "Whites",
                value: adjustmentBinding(\.whites),
                range: -1...1,
                format: "%.2f"
            )

            AdjustmentSlider(
                title: "Blacks",
                value: adjustmentBinding(\.blacks),
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
                title: "Hue",
                value: adjustmentBinding(\.hue),
                range: -180...180,
                format: "%.0f"
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

            Button {
                library.resetSelectedToneAdjustments()
            } label: {
                Label("Reset Tone", systemImage: "slider.horizontal.2.gobackward")
            }
            .disabled(library.selectedPhoto == nil)

            DisclosureGroup(isExpanded: $isLocalExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    AdjustmentSlider(
                        title: "Radial Exposure",
                        value: adjustmentBinding(\.radialExposure),
                        range: -2...2,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Center X",
                        value: adjustmentBinding(\.radialCenterX),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Center Y",
                        value: adjustmentBinding(\.radialCenterY),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Radius",
                        value: adjustmentBinding(\.radialRadius),
                        range: 0.05...0.8,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Feather",
                        value: adjustmentBinding(\.radialFeather),
                        range: 0.02...0.8,
                        format: "%.2f"
                    )

                    Toggle("Invert Mask", isOn: adjustmentBinding(\.radialInvert))
                        .disabled(library.selectedPhoto == nil)

                    Button {
                        library.resetSelectedRadialAdjustment()
                    } label: {
                        Label("Reset Radial", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
                .padding(.top, 8)
            } label: {
                Label("Local Radial", systemImage: "circle.dashed.inset.filled")
                    .font(.headline)
            }

            DisclosureGroup(isExpanded: $isLinearExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    AdjustmentSlider(
                        title: "Linear Exposure",
                        value: adjustmentBinding(\.linearExposure),
                        range: -2...2,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Start Y",
                        value: adjustmentBinding(\.linearStartY),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "End Y",
                        value: adjustmentBinding(\.linearEndY),
                        range: 0...1,
                        format: "%.2f"
                    )

                    Toggle("Invert Mask", isOn: adjustmentBinding(\.linearInvert))
                        .disabled(library.selectedPhoto == nil)

                    Button {
                        library.invertSelectedLinearGradientDirection()
                    } label: {
                        Label("Flip Direction", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(library.selectedPhoto == nil)

                    Button {
                        library.resetSelectedLinearAdjustment()
                    } label: {
                        Label("Reset Linear", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
                .padding(.top, 8)
            } label: {
                Label("Local Linear", systemImage: "rectangle.split.1x2")
                    .font(.headline)
            }

            DisclosureGroup(isExpanded: $isHealExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    AdjustmentSlider(
                        title: "Amount",
                        value: adjustmentBinding(\.spotHealAmount),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Target X",
                        value: adjustmentBinding(\.spotHealX),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Target Y",
                        value: adjustmentBinding(\.spotHealY),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Radius",
                        value: adjustmentBinding(\.spotHealRadius),
                        range: 0.01...0.2,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Feather",
                        value: adjustmentBinding(\.spotHealFeather),
                        range: 0.005...0.2,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Source X",
                        value: adjustmentBinding(\.spotHealSourceOffsetX),
                        range: -0.5...0.5,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Source Y",
                        value: adjustmentBinding(\.spotHealSourceOffsetY),
                        range: -0.5...0.5,
                        format: "%.2f"
                    )

                    Button {
                        library.resetSelectedSpotHeal()
                    } label: {
                        Label("Reset Spot", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
                .padding(.top, 8)
            } label: {
                Label("Spot Heal", systemImage: "bandage")
                    .font(.headline)
            }

            Button {
                library.resetSelectedLocalAdjustments()
            } label: {
                Label("Reset Local", systemImage: "scope")
            }
            .disabled(library.selectedPhoto == nil)

            DisclosureGroup(isExpanded: $isBeautyExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        library.autoBeautySelected()
                    } label: {
                        Label("Auto Beauty", systemImage: "sparkles")
                    }
                    .disabled(library.selectedPhoto == nil)

                    Text("Skin")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AdjustmentSlider(
                        title: "Smooth",
                        value: adjustmentBinding(\.beautySmooth),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Wrinkle",
                        value: adjustmentBinding(\.beautyWrinkle),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Blemish",
                        value: adjustmentBinding(\.beautyBlemish),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Whiten",
                        value: adjustmentBinding(\.beautyWhiten),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Rosy",
                        value: adjustmentBinding(\.beautyRosy),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Bright",
                        value: adjustmentBinding(\.beautyBrighten),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Tone Warmth",
                        value: adjustmentBinding(\.beautyWarmth),
                        range: -1...1,
                        format: "%.2f"
                    )

                    Text("Finish")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AdjustmentSlider(
                        title: "Glow",
                        value: adjustmentBinding(\.beautyGlow),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Soften",
                        value: adjustmentBinding(\.beautySoften),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Detail",
                        value: adjustmentBinding(\.beautyDetail),
                        range: 0...1,
                        format: "%.2f"
                    )

                    Text("Shape")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    AdjustmentSlider(
                        title: "Eye Enlarge",
                        value: adjustmentBinding(\.eyeEnlarge),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Face Slim",
                        value: adjustmentBinding(\.faceSlim),
                        range: 0...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Body Slim",
                        value: adjustmentBinding(\.bodySlim),
                        range: 0...1,
                        format: "%.2f"
                    )

                    Button {
                        library.resetSelectedBeautyAdjustments()
                    } label: {
                        Label("Reset Beauty", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
                .padding(.top, 8)
            } label: {
                Label("Beauty", systemImage: "sparkles")
                    .font(.headline)
            }

            DisclosureGroup(isExpanded: $isColorMixerExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    AdjustmentSlider(
                        title: "Red Sat",
                        value: colorMixerBinding(\.red),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Orange Sat",
                        value: colorMixerBinding(\.orange),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Yellow Sat",
                        value: colorMixerBinding(\.yellow),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Green Sat",
                        value: colorMixerBinding(\.green),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Aqua Sat",
                        value: colorMixerBinding(\.aqua),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Blue Sat",
                        value: colorMixerBinding(\.blue),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Purple Sat",
                        value: colorMixerBinding(\.purple),
                        range: -1...1,
                        format: "%.2f"
                    )

                    AdjustmentSlider(
                        title: "Magenta Sat",
                        value: colorMixerBinding(\.magenta),
                        range: -1...1,
                        format: "%.2f"
                    )

                    Button {
                        library.resetSelectedColorMixer()
                    } label: {
                        Label("Reset Mixer", systemImage: "arrow.counterclockwise.circle")
                    }
                    .disabled(library.selectedPhoto == nil)
                }
                .padding(.top, 8)
            } label: {
                Label("Color Mixer", systemImage: "paintpalette")
                    .font(.headline)
            }

            if let metadata = library.selectedPhoto?.metadata {
                Divider()

                DisclosureGroup(isExpanded: $isInfoExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "Dimensions", value: metadata.dimensionsText)
                        InfoRow(label: "Resolution", value: metadata.megapixelsText)
                        InfoRow(label: "File Size", value: metadata.fileSizeText)
                        InfoRow(label: "Format", value: metadata.formatText)
                        if let captureDateText = metadata.captureDateText {
                            InfoRow(label: "Captured", value: captureDateText)
                        }
                        if let cameraText = metadata.cameraText {
                            InfoRow(label: "Camera", value: cameraText)
                        }
                        if let lensModel = metadata.lensModel {
                            InfoRow(label: "Lens", value: lensModel)
                        }
                        if let exposureText = metadata.exposureText {
                            InfoRow(label: "Exposure", value: exposureText)
                        }
                        if let focalLengthText = metadata.focalLengthText {
                            InfoRow(label: "Focal Length", value: focalLengthText)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Info", systemImage: "info.circle")
                        .font(.headline)
                }
            }

            Divider()

            DisclosureGroup(isExpanded: $isExportExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Format", selection: $library.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Menu {
                        ForEach(ExportPreset.allCases) { preset in
                            Button(preset.rawValue) {
                                library.applyExportPreset(preset)
                            }
                        }
                    } label: {
                        Label("Export Preset", systemImage: "square.and.arrow.up.on.square")
                    }

                    AdjustmentSlider(
                        title: "JPEG Quality",
                        value: $library.exportQuality,
                        range: 0.5...1,
                        format: "%.2f"
                    )
                    .disabled(library.exportFormat != .jpeg)

                    AdjustmentSlider(
                        title: "Long Edge",
                        value: $library.exportLongEdge,
                        range: 0...6000,
                        format: "%.0f"
                    )

                    Toggle("Add -luma Suffix", isOn: $library.exportAddsLumaSuffix)

                    Button {
                        library.resetExportSettings()
                    } label: {
                        Label("Reset Export Settings", systemImage: "arrow.counterclockwise.circle")
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.headline)
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

    private func adjustmentBinding(_ keyPath: WritableKeyPath<PhotoAdjustments, Bool>) -> Binding<Bool> {
        Binding {
            library.selectedAdjustments[keyPath: keyPath]
        } set: { value in
            library.updateSelectedAdjustments { adjustments in
                adjustments[keyPath: keyPath] = value
            }
        }
    }

    private func colorMixerBinding(_ keyPath: WritableKeyPath<ColorMixerAdjustments, Double>) -> Binding<Double> {
        Binding {
            library.selectedAdjustments.colorMixer[keyPath: keyPath]
        } set: { value in
            library.updateSelectedAdjustments { adjustments in
                adjustments.colorMixer[keyPath: keyPath] = value
            }
        }
    }
}

struct HistogramView: View {
    let luminanceBins: [Double]
    let rgbBins: RGBHistogram?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Histogram")
                    .font(.headline)

                Spacer()

                HStack(spacing: 6) {
                    HistogramLegendItem(color: .secondary, label: "L")
                    HistogramLegendItem(color: .red, label: "R")
                    HistogramLegendItem(color: .green, label: "G")
                    HistogramLegendItem(color: .blue, label: "B")
                }
            }

            GeometryReader { geometry in
                let barWidth = max(1, geometry.size.width / CGFloat(max(1, luminanceBins.count)))

                ZStack(alignment: .bottomLeading) {
                    if let rgbBins {
                        histogramBars(values: rgbBins.red, color: .red.opacity(0.38), barWidth: barWidth, height: geometry.size.height)
                        histogramBars(values: rgbBins.green, color: .green.opacity(0.38), barWidth: barWidth, height: geometry.size.height)
                        histogramBars(values: rgbBins.blue, color: .blue.opacity(0.38), barWidth: barWidth, height: geometry.size.height)
                    }

                    histogramBars(values: luminanceBins, color: .secondary.opacity(0.55), barWidth: barWidth, height: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func histogramBars(values: [Double], color: Color, barWidth: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Rectangle()
                    .fill(color)
                    .frame(width: barWidth, height: max(2, height * value))
            }
        }
    }
}

struct HistogramLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ColorLabelButton: View {
    let colorLabel: PhotoColorLabel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(colorLabel.displayColor)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isSelected ? 3 : 1)
                }
                .overlay {
                    if colorLabel == .none {
                        Image(systemName: "slash")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(colorLabel.rawValue)
    }
}

private extension PhotoColorLabel {
    var displayColor: Color {
        switch self {
        case .none:
            Color(nsColor: .controlBackgroundColor)
        case .red:
            .red
        case .yellow:
            .yellow
        case .green:
            .green
        case .blue:
            .blue
        case .purple:
            .purple
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
                    .foregroundStyle(value <= rating ? Color.yellow : Color.secondary.opacity(0.35))
            }
        }
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
