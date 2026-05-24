import SwiftUI

@main
struct LumaApp: App {
    @StateObject private var library = PhotoLibraryStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(library)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    library.undoAdjustment()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(!library.canUndo)

                Button("Redo") {
                    library.redoAdjustment()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!library.canRedo)
            }

            CommandGroup(replacing: .newItem) {
                Button("Open Photos...") {
                    library.importPhotos()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Import Photos...") {
                    library.importPhotos()
                }
                .keyboardShortcut("i", modifiers: [.command])
            }

            CommandMenu("Photo") {
                Button("Copy Adjustments") {
                    library.copySelectedAdjustments()
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(library.selectedPhoto == nil)

                Button("Paste Adjustments") {
                    library.pasteAdjustmentsToSelected()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(library.selectedPhoto == nil)

                Button("Sync Adjustments to Picked") {
                    library.syncSelectedAdjustmentsToPicked()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(library.selectedPhoto == nil || library.pickedPhotoCount <= 1)

                Divider()

                Button("Auto Enhance") {
                    library.autoEnhanceSelected()
                }
                .keyboardShortcut("u", modifiers: [.command])
                .disabled(library.selectedPhoto == nil)

                Button("Auto Beauty") {
                    library.autoBeautySelected()
                }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(library.selectedPhoto == nil)

                Button("Show Original") {
                    library.showOriginal.toggle()
                }
                .keyboardShortcut("\\", modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Button("Compare Side by Side") {
                    library.toggleCompareSideBySide()
                }
                .keyboardShortcut("y", modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Divider()

                Button("Pick") {
                    library.setSelectedFlag(.picked)
                }
                .keyboardShortcut("p", modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Button("Reject") {
                    library.setSelectedFlag(.rejected)
                }
                .keyboardShortcut("x", modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Button("Clear Flag") {
                    library.setSelectedFlag(.none)
                }
                .keyboardShortcut("u", modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Divider()

                Button("Remove From Library") {
                    library.removeSelectedPhoto()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(library.selectedPhoto == nil)

                Divider()

                Button("Rotate Left") {
                    library.rotateSelectedLeft()
                }
                .keyboardShortcut("l", modifiers: [.command])
                .disabled(library.selectedPhoto == nil)

                Button("Rotate Right") {
                    library.rotateSelectedRight()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(library.selectedPhoto == nil)

                Divider()

                Button("Export JPEG...") {
                    library.exportSelectedPhoto()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(library.selectedPhoto == nil)

                Button("Export Picked Photos...") {
                    library.exportPickedPhotos()
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(library.pickedPhotoCount == 0)
            }
        }
    }
}
