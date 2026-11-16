import Foundation
import SwiftData

@Model
final class Notebook {
    var title: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var coverColorHex: String = "#7A5CFA"
    var paperStyleRaw: String = PaperStyle.lined.rawValue
    var folder: Folder?
    @Relationship(deleteRule: .cascade, inverse: \Page.notebook) var pages: [Page]? = []

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .lined }
        set { paperStyleRaw = newValue.rawValue }
    }

    var sortedPages: [Page] {
        (pages ?? []).sorted { $0.index < $1.index }
    }

    init(title: String, paperStyle: PaperStyle = .lined, folder: Folder? = nil) {
        self.title = title
        self.paperStyleRaw = paperStyle.rawValue
        self.folder = folder
    }

    @discardableResult
    func addPage() -> Page {
        let page = Page(index: (pages ?? []).count)
        page.notebook = self
        pages = (pages ?? []) + [page]
        modifiedAt = Date()
        return page
    }
}
