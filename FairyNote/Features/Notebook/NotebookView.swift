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
    @State private var showPaper = false

    @State private var viewport = PageViewport()

    var body: some View {
        VStack(spacing: 0) {
            ToolBarView(tools: tools)
                .zIndex(1)
            pages
        }
        .background(theme.desk)
        .toolbarBackground(theme.desk, for: .navigationBar)
        .navigationTitle($notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewport.isTransformed {
                Button("Ansicht zurücksetzen", systemImage: "arrow.counterclockwise") { viewport.reset() }
            }
            Button("Papier", systemImage: "doc.richtext") { showPaper = true }
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
        .sheet(isPresented: $showPaper) {
            PaperSettingsSheet(notebook: notebook) { AutoSaver.schedule(context) }
        }
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
        .onDisappear {
            viewport.detach()
            AutoSaver.saveNow(context)
        }
    }

    /// Seitenspalte in einer drehbaren, zoombaren ScrollView.
    private var pages: some View {
        GeometryReader { geo in
            let layout = ViewportLayout(size: geo.size)
            let zoom = viewport.zoom
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                LazyVStack(spacing: PageViewport.pageSpacing * zoom) {
                    ForEach(notebook.sortedPages) { page in
                        VStack(spacing: 8 * zoom) {
                            PageView(page: page, paperStyle: notebook.paperStyle, paperColor: notebook.paperColor,
                                     pdfPage: page.pdfPageIndex.flatMap { pdf?.page(at: $0) }, tools: tools) {
                                notebook.touch()
                                AutoSaver.schedule(context)
                            }
                            .frame(width: layout.baseWidth * zoom)
                            .shadow(color: .black.opacity(theme.scheme == .dark ? 0.4 : 0.06), radius: 2, y: 1)
                            .shadow(color: .black.opacity(theme.scheme == .dark ? 0.5 : 0.10), radius: 18, y: 10)

                            pageFooter(page, zoom: zoom)
                                .frame(width: layout.baseWidth * zoom, height: 32 * zoom)
                        }
                    }
                }
                .padding(PageViewport.pagePadding * zoom)
                .padding(.horizontal, layout.margin.width)
                .padding(.vertical, layout.margin.height)
                .frame(minWidth: layout.diagonal)
                .background(ScrollViewFinder { viewport.attach(to: $0) })
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollDismissesKeyboard(.immediately)
            .frame(width: layout.diagonal, height: layout.diagonal)
            .rotationEffect(viewport.displayRotation)
            .scaleEffect(viewport.liveScale, anchor: viewport.scaleAnchor)
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { viewport.layout = layout }
            .onChange(of: layout) { viewport.layout = layout }
        }
        .clipped()
        .ignoresSafeArea()
    }

    private func pageFooter(_ page: Page, zoom: CGFloat) -> some View {
        HStack {
            Text("Seite \(page.index + 1) von \(notebook.sortedPages.count)")
                .font(.system(size: 13 * zoom))
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
                    .font(.system(size: 20 * zoom))
                    .foregroundStyle(theme.secondaryInk)
                    .padding(4 * zoom)
            }
        }
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
    @Environment(\.theme) private var theme
    @Bindable var page: Page
    let paperStyle: PaperStyle
    let paperColor: PaperColor
    let pdfPage: PDFPage?
    let tools: ToolState
    let onChange: () -> Void

    var body: some View {
        GeometryReader { geo in
            // Alles wird in der tatsächlichen Anzeigegröße gezeichnet (auch gezoomt scharf),
            // die Striche bleiben im festen Seitenkoordinatensystem (`Page.canvasWidth`).
            let scale = geo.size.width / Page.canvasWidth
            ZStack {
                if let pdfPage {
                    TiledPageBackground(content: .pdf(pdfPage))
                } else {
                    let hexes = paperColor.hexes(for: theme)
                    TiledPageBackground(content: .paper(paperStyle, paper: UIColor(hex: hexes.paper),
                                                        line: UIColor(hex: hexes.line)))
                }
                CanvasView(drawingData: $page.drawingData,
                           tool: tools.pkTool,
                           toolSignature: tools.signature,
                           fingerDrawing: tools.fingerDrawing,
                           scale: scale,
                           darkPaper: pdfPage == nil && paperColor.isDark(for: theme),
                           onBegin: { tools.activeCanvas = $0 },
                           onChange: onChange)
            }
        }
        .aspectRatio(page.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
