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
                Button("Export JPEG...") {
                    library.exportSelectedPhoto()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(library.selectedPhoto == nil)
            }
        }
    }
}
