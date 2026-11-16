import SwiftUI
import SwiftData

@main
struct FairyNoteApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(for: [Folder.self, Notebook.self, Page.self])
    }
}
