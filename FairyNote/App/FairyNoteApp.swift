import SwiftUI
import SwiftData

@main
struct FairyNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        Theme.setUp()
        do {
            container = try ModelContainer(for: Folder.self, Notebook.self, Page.self)
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Vor dem Beenden/Wechseln alles sichern, damit nichts verloren geht.
            if phase != .active { AutoSaver.saveNow(container.mainContext) }
        }
    }
}
