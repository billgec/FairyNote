import UIKit
import PDFKit
import PencilKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf, fairyNote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "Als PDF (z. B. für GoodNotes)"
        case .fairyNote: "Als FairyNote-Datei"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.richtext"
        case .fairyNote: "book.closed"
        }
    }
}

/// Schreibt ein Notizbuch als Datei in einen temporären Ordner, bereit zum Teilen.
@MainActor
enum NotebookExporter {
    static func export(_ notebook: Notebook, as format: ExportFormat) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let name = fileName(notebook.title)
        switch format {
        case .pdf:
            let url = dir.appendingPathComponent(name).appendingPathExtension("pdf")
            try pdfData(notebook).write(to: url)
            return url
        case .fairyNote:
            let url = dir.appendingPathComponent(name).appendingPathExtension("fairynote")
            try NotebookArchive(notebook).encoded().write(to: url)
            return url
        }
    }

    /// Hintergrund (Papier oder Original-PDF-Seite, vektoriell) + Handschrift (als Bild) pro Seite.
    static func pdfData(_ notebook: Notebook) -> Data {
        let background = notebook.backgroundPDF.flatMap { PDFDocument(data: $0) }
        let info: [String: Any] = [
            kCGPDFContextTitle as String: notebook.title,
            kCGPDFContextCreator as String: "FairyNote",
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = info
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: CGSize(width: 595.28, height: 841.89)),
                                             format: format)
        // Striche immer in hellen Farben rendern, auch wenn das iPad im Dunkelmodus ist.
        let light = UITraitCollection(userInterfaceStyle: .light)

        return renderer.pdfData { ctx in
            for page in notebook.sortedPages {
                let rect = CGRect(x: 0, y: 0, width: page.width, height: page.height)
                ctx.beginPage(withBounds: rect, pageInfo: [:])
                let cg = ctx.cgContext

                if let index = page.pdfPageIndex, let pdfPage = background?.page(at: index) {
                    cg.setFillColor(UIColor.white.cgColor)
                    cg.fill(rect)
                    PDFPageDrawing.draw(pdfPage, in: cg, size: rect.size)
                } else {
                    PaperPattern.draw(notebook.paperStyle, in: cg, size: rect.size)
                }

                guard let data = page.drawingData, let drawing = try? PKDrawing(data: data),
                      !drawing.strokes.isEmpty else { continue }
                var image = UIImage()
                light.performAsCurrent {
                    image = drawing.image(from: CGRect(origin: .zero, size: page.canvasSize), scale: 2)
                }
                image.draw(in: rect)
            }
        }
    }

    private static func fileName(_ title: String) -> String {
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Notizbuch" : cleaned
    }
}
