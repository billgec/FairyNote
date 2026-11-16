import SwiftUI
import SwiftData
import PencilKit

struct NotebookView: View {
    @Environment(\.modelContext) private var context
    @Bindable var notebook: Notebook
    @State private var tools = ToolState()
    @State private var pageToDelete: Page?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(notebook.sortedPages) { page in
                    VStack(spacing: 8) {
                        PageView(page: page, paperStyle: notebook.paperStyle, tools: tools) {
                            notebook.touch()
                            AutoSaver.schedule(context)
                        }
                        .aspectRatio(PageView.aspectRatio, contentMode: .fit)
                        .frame(maxWidth: 900)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                        pageFooter(page)
                    }
                }
            }
            .padding(32)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color(.secondarySystemBackground))
        .safeAreaInset(edge: .top, spacing: 0) { ToolBarView(tools: tools) }
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
                AutoSaver.saveNow(context)
            }
        }
        .confirmationDialog("Seite löschen?", isPresented: isDeleting, titleVisibility: .visible) {
            Button("Seite löschen", role: .destructive) {
                if let page = pageToDelete {
                    notebook.deletePage(page, in: context)
                    AutoSaver.saveNow(context)
                }
            }
        } message: {
            Text("Die Zeichnung auf dieser Seite geht verloren.")
        }
        .onDisappear { AutoSaver.saveNow(context) }
    }

    private func pageFooter(_ page: Page) -> some View {
        HStack {
            Text("Seite \(page.index + 1) von \(notebook.sortedPages.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button("Neue Seite davor", systemImage: "arrow.up.doc") {
                    notebook.addPage(at: page.index)
                    AutoSaver.saveNow(context)
                }
                Button("Neue Seite danach", systemImage: "arrow.down.doc") {
                    notebook.addPage(at: page.index + 1)
                    AutoSaver.saveNow(context)
                }
                Button("Duplizieren", systemImage: "plus.square.on.square") {
                    notebook.duplicatePage(page)
                    AutoSaver.saveNow(context)
                }
                Divider()
                Button("Seite löschen", systemImage: "trash", role: .destructive) {
                    pageToDelete = page
                }
                .disabled(notebook.sortedPages.count <= 1)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .padding(4)
            }
        }
        .frame(maxWidth: 900)
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } })
    }
}

struct PageView: View {
    static let aspectRatio: CGFloat = 1 / 1.414 // DIN A4

    @Bindable var page: Page
    let paperStyle: PaperStyle
    let tools: ToolState
    let onChange: () -> Void

    var body: some View {
        ZStack {
            PaperBackground(style: paperStyle)
            CanvasView(drawingData: $page.drawingData,
                       tool: tools.pkTool,
                       toolSignature: tools.signature,
                       fingerDrawing: tools.fingerDrawing,
                       onBegin: { tools.activeCanvas = $0 },
                       onChange: onChange)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
