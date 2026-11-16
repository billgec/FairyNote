import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Notebook.modifiedAt, order: .reverse) private var notebooks: [Notebook]
    @State private var path = NavigationPath()

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 24)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(notebooks) { notebook in
                        NavigationLink(value: notebook) {
                            NotebookCover(notebook: notebook)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                context.delete(notebook)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .overlay {
                if notebooks.isEmpty {
                    ContentUnavailableView("Noch keine Notizbücher",
                                           systemImage: "book.closed",
                                           description: Text("Tippe auf + um loszulegen."))
                }
            }
            .navigationTitle("FairyNote")
            .toolbar {
                Button("Neues Notizbuch", systemImage: "plus", action: createNotebook)
            }
            .navigationDestination(for: Notebook.self) { NotebookView(notebook: $0) }
        }
    }

    private func createNotebook() {
        let notebook = Notebook(title: "Notizbuch \(notebooks.count + 1)")
        context.insert(notebook)
        notebook.addPage()
        path.append(notebook)
    }
}

struct NotebookCover: View {
    let notebook: Notebook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: notebook.coverColorHex).gradient)
                .aspectRatio(0.75, contentMode: .fit)
                .overlay(alignment: .bottomLeading) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                }
                .shadow(radius: 3, y: 2)
            Text(notebook.title).font(.headline).lineLimit(1)
            Text(notebook.modifiedAt, style: .date).font(.caption).foregroundStyle(.secondary)
        }
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
