import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Eigenes, verlustfreies Austauschformat (.fairynote).
    static let fairyNote = UTType(exportedAs: "com.billgec.fairynote.notebook")
    /// GoodNotes-Notizbuch. Ist GoodNotes installiert, gilt dessen Typ, sonst unsere Deklaration.
    static let goodNotes = UTType(filenameExtension: "goodnotes") ?? UTType(importedAs: "com.goodnotesapp.goodnotes")
}

/// Inhalt einer .fairynote-Datei: das ganze Notizbuch inkl. bearbeitbarer Striche und PDF-Hintergrund.
/// Gespeichert als binäre Property List, damit Daten (Zeichnungen, PDF) ohne Umweg über Base64 drin landen.
struct NotebookArchive: Codable {
    static let currentVersion = 1

    struct PageEntry: Codable {
        var drawing: Data?
        var pdfPageIndex: Int?
        var width: Double
        var height: Double
        var recognizedText: String?
    }

    var version = Self.currentVersion
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var coverColorHex: String
    var paperStyle: String
    var backgroundPDF: Data?
    var pages: [PageEntry]

    init(_ notebook: Notebook) {
        title = notebook.title
        createdAt = notebook.createdAt
        modifiedAt = notebook.modifiedAt
        coverColorHex = notebook.coverColorHex
        paperStyle = notebook.paperStyleRaw
        backgroundPDF = notebook.backgroundPDF
        pages = notebook.sortedPages.map {
            PageEntry(drawing: $0.drawingData, pdfPageIndex: $0.pdfPageIndex,
                      width: $0.width, height: $0.height, recognizedText: $0.recognizedText)
        }
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> NotebookArchive {
        let archive = try PropertyListDecoder().decode(NotebookArchive.self, from: data)
        guard archive.version <= currentVersion else { throw NotebookImporter.ImportError.newerVersion }
        return archive
    }
}
