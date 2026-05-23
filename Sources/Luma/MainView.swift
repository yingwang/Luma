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
                    library.exportSelectedPhoto()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(library.selectedPhoto == nil)
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

                Text("\(library.photos.count)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if library.photos.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("Import local photos to start editing.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(library.photos) { photo in
                            PhotoGridCell(
                                photo: photo,
                                isSelected: photo.id == library.selectedPhotoID
                            )
                            .onTapGesture {
                                library.select(photo)
                            }
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

            Text(photo.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(4)
        .contentShape(Rectangle())
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

            AdjustmentSlider(
                title: "Exposure",
                value: adjustmentBinding(\.exposure),
                range: -3...3,
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

            Button {
                library.resetSelectedAdjustments()
            } label: {
                Label("Reset Adjustments", systemImage: "arrow.counterclockwise")
            }
            .disabled(library.selectedPhoto == nil)

            Spacer()
        }
        .padding(18)
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
