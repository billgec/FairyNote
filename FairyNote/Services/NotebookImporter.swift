import Foundation
import PDFKit
import SwiftData
import UniformTypeIdentifiers

/// Legt aus einer PDF- oder .fairynote-Datei ein neues Notizbuch an.
@MainActor
enum NotebookImporter {
    enum ImportError: LocalizedError {
        case unreadablePDF, lockedPDF, emptyPDF, unsupported(String), newerVersion

        var errorDescription: String? {
            switch self {
            case .unreadablePDF: "Die PDF-Datei konnte nicht gelesen werden."
            case .lockedPDF: "Das PDF ist passwortgeschützt. Bitte ohne Passwort exportieren."
            case .emptyPDF: "Das PDF enthält keine Seiten."
            case .unsupported(let ext):
                ext == "goodnotes"
                    ? "GoodNotes-Dateien (.goodnotes) sind ein geschlossenes Format. Bitte in GoodNotes über Teilen › Exportieren › PDF exportieren und das PDF importieren."
                    : "Dieser Dateityp wird nicht unterstützt (.\(ext))."
            case .newerVersion: "Die Datei stammt aus einer neueren FairyNote-Version. Bitte die App aktualisieren."
            }
        }
    }

    static let importableTypes: [UTType] = [.pdf, .fairyNote]

    static func importFile(at url: URL, into context: ModelContext, folder: Folder?) throws -> Notebook {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        let title = url.deletingPathExtension().lastPathComponent

        let notebook: Notebook
        if ext == "fairynote" {
            notebook = try importArchive(data, into: context)
        } else if ext == "pdf" || data.starts(with: Data("%PDF".utf8)) {
            notebook = try importPDF(data, title: title, into: context)
        } else {
            throw ImportError.unsupported(ext)
        }
        notebook.folder = folder
        AutoSaver.saveNow(context)
        return notebook
    }

    /// Jede PDF-Seite wird eine Notizbuch-Seite mit dem PDF als Hintergrund, darauf kann weiter geschrieben werden.
    static func importPDF(_ data: Data, title: String, into context: ModelContext) throws -> Notebook {
        guard let document = PDFDocument(data: data) else { throw ImportError.unreadablePDF }
        guard !document.isLocked else { throw ImportError.lockedPDF }
        guard document.pageCount > 0 else { throw ImportError.emptyPDF }

        let covers = AppTheme.current.covers
        let cover = covers.randomElement()?.hex ?? covers[0].hex
        let notebook = Notebook(title: title, paperStyle: .blank, coverColorHex: cover)
        notebook.backgroundPDF = data
        context.insert(notebook)
        var index = 0
        for i in 0..<document.pageCount {
            guard let pdfPage = document.page(at: i) else { continue }
            let size = PDFPageDrawing.size(of: pdfPage)
            let page = Page(index: index)
            index += 1
            page.pdfPageIndex = i
            if size.width > 0, size.height > 0 {
                page.width = size.width
                page.height = size.height
            }
            context.insert(page)
            page.notebook = notebook
        }
        return notebook
    }

    static func importArchive(_ data: Data, into context: ModelContext) throws -> Notebook {
        let archive = try NotebookArchive.decode(data)
        let notebook = Notebook(title: archive.title,
                                paperStyle: PaperStyle(rawValue: archive.paperStyle) ?? .lined,
                                coverColorHex: archive.coverColorHex)
        notebook.createdAt = archive.createdAt
        notebook.backgroundPDF = archive.backgroundPDF
        context.insert(notebook)
        for (i, entry) in archive.pages.enumerated() {
            let page = Page(index: i)
            page.drawingData = entry.drawing
            page.pdfPageIndex = entry.pdfPageIndex
            page.width = entry.width
            page.height = entry.height
            page.recognizedText = entry.recognizedText
            context.insert(page)
            page.notebook = notebook
        }
        if archive.pages.isEmpty { notebook.addPage() }
        // Zeitstempel aus der Datei behalten (addPage/insert setzen sie sonst neu).
        notebook.modifiedAt = archive.modifiedAt
        return notebook
    }
}
