#if DEBUG
import SwiftData

/// Beispielinhalte für Screenshots im Simulator. Start mit dem Argument `-sampleData`.
enum SampleData {
    @MainActor
    static func insert(into context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Notebook>())) ?? 0) == 0 else { return }
        let uni = Folder(name: "Semester 3")
        let exams = Folder(name: "Prüfungen")
        context.insert(uni)
        context.insert(exams)
        let covers = AppTheme.current.covers
        let titles = ["Zellbiologie", "Statistik II", "Seminar Ethik", "Anatomie", "Lernplan", "Chemie", "Tagebuch", "Skizzen"]
        for (i, title) in titles.enumerated() {
            let notebook = Notebook(title: title, paperStyle: [.lined, .grid, .dotted][i % 3],
                                    coverColorHex: covers[i % covers.count].hex,
                                    folder: i < 4 ? uni : (i == 4 ? exams : nil))
            notebook.createdAt = Date(timeIntervalSince1970: Double(1_700_000_000 + i * 7))
            notebook.modifiedAt = Date().addingTimeInterval(Double(-i) * 86_400)
            context.insert(notebook)
            notebook.addPage()
        }
        try? context.save()
    }
}
#endif
