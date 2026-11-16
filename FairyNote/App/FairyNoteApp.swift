import SwiftUI
import SwiftData

@main
struct FairyNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.standard.id
    private let container: ModelContainer

    init() {
        Theme.setUp()
        do {
            container = try ModelContainer(for: Folder.self, Notebook.self, Page.self)
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sampleData") { SampleData.insert(into: container.mainContext) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            let theme = AppTheme.named(themeID)
            LibraryView()
                .environment(\.theme, theme)
                .tint(theme.accent)
                .preferredColorScheme(theme.scheme)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Vor dem Beenden/Wechseln alles sichern, damit nichts verloren geht.
            if phase != .active { AutoSaver.saveNow(container.mainContext) }
        }
    }
}
