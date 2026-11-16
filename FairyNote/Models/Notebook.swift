import Foundation
import SwiftData

@Model
final class Notebook {
    var title: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var coverColorHex: String = "#FF5A3C"
    var paperStyleRaw: String = PaperStyle.lined.rawValue
    var paperColorRaw: String = PaperColor.theme.rawValue
    var folder: Folder?
    /// Importiertes PDF, dessen Seiten als Hintergrund dienen (siehe `Page.pdfPageIndex`).
    @Attribute(.externalStorage) var backgroundPDF: Data?
    @Relationship(deleteRule: .cascade, inverse: \Page.notebook) var pages: [Page]? = []

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .lined }
        set { paperStyleRaw = newValue.rawValue; touch() }
    }

    var paperColor: PaperColor {
        get { PaperColor(rawValue: paperColorRaw) ?? .theme }
        set { paperColorRaw = newValue.rawValue; touch() }
    }

    var sortedPages: [Page] {
        (pages ?? []).sorted { $0.index < $1.index }
    }

    init(title: String, paperStyle: PaperStyle = .lined, paperColor: PaperColor = .theme,
         coverColorHex: String = "#FF5A3C", folder: Folder? = nil) {
        self.title = title
        self.paperStyleRaw = paperStyle.rawValue
        self.paperColorRaw = paperColor.rawValue
        self.coverColorHex = coverColorHex
        self.folder = folder
    }

    func touch() { modifiedAt = Date() }

    /// Fügt eine leere Seite ein, standardmäßig am Ende.
    @discardableResult
    func addPage(at position: Int? = nil) -> Page {
        let pages = sortedPages
        let index = min(max(position ?? pages.count, 0), pages.count)
        for page in pages where page.index >= index { page.index += 1 }
        let page = Page(index: index)
        // Neue Seiten übernehmen das Format der Nachbarseite (wichtig bei Querformat-PDFs).
        if let neighbor = index > 0 ? pages[index - 1] : pages.first {
            page.width = neighbor.width
            page.height = neighbor.height
        }
        page.notebook = self
        self.pages = pages + [page]
        touch()
        return page
    }

    /// Kopiert eine Seite samt Zeichnung direkt hinter das Original.
    @discardableResult
    func duplicatePage(_ page: Page) -> Page {
        let copy = addPage(at: page.index + 1)
        copy.drawingData = page.drawingData
        copy.pdfPageIndex = page.pdfPageIndex
        return copy
    }

    /// Entfernt eine Seite und nummeriert die übrigen neu. Die letzte Seite bleibt immer erhalten.
    func deletePage(_ page: Page, in context: ModelContext) {
        guard (pages ?? []).count > 1 else { return }
        pages?.removeAll { $0 == page }
        context.delete(page)
        for (i, p) in sortedPages.enumerated() { p.index = i }
        touch()
    }
}
