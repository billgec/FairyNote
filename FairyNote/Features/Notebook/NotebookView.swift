import SwiftUI
import SwiftData
import PencilKit
import PDFKit

struct NotebookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Bindable var notebook: Notebook
    @State private var tools = ToolState()
    @State private var pageToDelete: Page?
    @State private var pdf: PDFDocument?
    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(notebook.sortedPages) { page in
                    VStack(spacing: 8) {
                        PageView(page: page, paperStyle: notebook.paperStyle,
                                 pdfPage: page.pdfPageIndex.flatMap { pdf?.page(at: $0) }, tools: tools) {
                            notebook.touch()
                            AutoSaver.schedule(context)
                        }
                        .frame(maxWidth: 900)
                        .shadow(color: .black.opacity(theme.scheme == .dark ? 0.4 : 0.06), radius: 2, y: 1)
                        .shadow(color: .black.opacity(theme.scheme == .dark ? 0.5 : 0.10), radius: 18, y: 10)

                        pageFooter(page)
                    }
                }
            }
            .padding(32)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(theme.desk)
        .safeAreaInset(edge: .top, spacing: 0) { ToolBarView(tools: tools) }
        .toolbarBackground(theme.desk, for: .navigationBar)
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
            Menu("Exportieren", systemImage: "square.and.arrow.up") {
                ForEach(ExportFormat.allCases) { format in
                    Button(format.title, systemImage: format.systemImage) { export(as: format) }
                }
            }
        }
        .task(id: notebook.backgroundPDF?.count) {
            pdf = notebook.backgroundPDF.flatMap { PDFDocument(data: $0) }
        }
        .sheet(item: $shareItem) { ShareSheet(url: $0.url) }
        .alert("Export fehlgeschlagen", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
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
                .foregroundStyle(theme.secondaryInk)
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
                    .foregroundStyle(theme.secondaryInk)
                    .padding(4)
            }
        }
        .frame(maxWidth: 900)
    }

    private func export(as format: ExportFormat) {
        AutoSaver.saveNow(context)
        do {
            shareItem = ShareItem(url: try NotebookExporter.export(notebook, as: format))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } })
    }
}

struct PageView: View {
    @Bindable var page: Page
    let paperStyle: PaperStyle
    let pdfPage: PDFPage?
    let tools: ToolState
    let onChange: () -> Void

    var body: some View {
        GeometryReader { geo in
            // Inhalt in fester Seitengröße aufbauen und auf die verfügbare Breite skalieren.
            ZStack {
                if let pdfPage {
                    PDFPageBackground(page: pdfPage)
                } else {
                    PaperBackground(style: paperStyle)
                }
                CanvasView(drawingData: $page.drawingData,
                           tool: tools.pkTool,
                           toolSignature: tools.signature,
                           fingerDrawing: tools.fingerDrawing,
                           onBegin: { tools.activeCanvas = $0 },
                           onChange: onChange)
            }
            .frame(width: page.canvasSize.width, height: page.canvasSize.height)
            .scaleEffect(geo.size.width / Page.canvasWidth, anchor: .topLeading)
        }
        .aspectRatio(page.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
