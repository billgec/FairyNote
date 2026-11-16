import Foundation
import SwiftData

@Model
final class Notebook {
    static let coverColors = ["#7A5CFA", "#E5677A", "#F2A541", "#4CAF8E", "#3E8ED0", "#5B6770"]

    var title: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var coverColorHex: String = "#7A5CFA"
    var paperStyleRaw: String = PaperStyle.lined.rawValue
    var folder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Page.notebook) var pages: [Page]? = []

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .lined }
        set { paperStyleRaw = newValue.rawValue; touch() }
    }

    var sortedPages: [Page] {
        (pages ?? []).sorted { $0.index < $1.index }
    }

    init(title: String, paperStyle: PaperStyle = .lined, coverColorHex: String = "#7A5CFA", folder: Folder? = nil) {
        self.title = title
        self.paperStyleRaw = paperStyle.rawValue
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
