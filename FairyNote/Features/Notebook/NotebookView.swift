import SwiftUI
import SwiftData

struct NotebookView: View {
    @Bindable var notebook: Notebook

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                ForEach(notebook.sortedPages) { page in
                    PageView(page: page, paperStyle: notebook.paperStyle)
                        .aspectRatio(PageView.aspectRatio, contentMode: .fit)
                        .frame(maxWidth: 900)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
            }
            .padding(32)
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle($notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu("Papier", systemImage: "doc.richtext") {
                Picker("Papier", selection: $notebook.paperStyle) {
                    ForEach(PaperStyle.allCases) { Text($0.title).tag($0) }
                }
            }
            Button("Seite hinzufügen", systemImage: "doc.badge.plus") {
                notebook.addPage()
            }
        }
    }
}

struct PageView: View {
    static let aspectRatio: CGFloat = 1 / 1.414 // DIN A4

    @Bindable var page: Page
    let paperStyle: PaperStyle

    var body: some View {
        ZStack {
            PaperBackground(style: paperStyle)
            CanvasView(drawingData: $page.drawingData)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
