import UIKit
import PDFKit
import PencilKit
import SwiftData

/// Wandelt ein GoodNotes-Dokument in ein FairyNote-Notizbuch um:
/// Vorlage/PDF-Seite und nicht umwandelbare Umrisse landen vektoriell im Hintergrund-PDF,
/// Kugelschreiber-, Textmarker- und Bleistiftstriche werden bearbeitbare PencilKit-Striche.
@MainActor
enum GoodNotesImporter {
    struct Result {
        let notebook: Notebook
        let skippedElements: Int
    }

    static func importNotebook(_ data: Data, title: String, into context: ModelContext) throws -> Result {
        let document = try GoodNotesDocument(data: data)
        guard !document.pages.isEmpty else { throw GoodNotesDocument.ImportFailure.notGoodNotes }

        let covers = AppTheme.current.covers
        let notebook = Notebook(title: title, paperStyle: .blank,
                                coverColorHex: covers.randomElement()?.hex ?? covers[0].hex)
        notebook.backgroundPDF = backgroundPDF(document)
        context.insert(notebook)

        let light = UITraitCollection(userInterfaceStyle: .light)
        for (i, gnPage) in document.pages.enumerated() {
            let page = Page(index: i)
            page.width = gnPage.size.width * GoodNotesDocument.pointsPerUnit
            page.height = gnPage.size.height * GoodNotesDocument.pointsPerUnit
            page.pdfPageIndex = i
            // GoodNotes-Einheiten → feste Zeichenbreite von FairyNote
            let scale = Page.canvasWidth / gnPage.size.width
            var strokes: [PKStroke] = []
            light.performAsCurrent {
                strokes = gnPage.strokes.compactMap { pkStroke($0, scale: scale) }
            }
            if !strokes.isEmpty { page.drawingData = PKDrawing(strokes: strokes).dataRepresentation() }
            context.insert(page)
            page.notebook = notebook
        }
        return Result(notebook: notebook, skippedElements: document.pages.reduce(0) { $0 + $1.skippedElements })
    }

    private static func pkStroke(_ s: GoodNotesDocument.Stroke, scale: CGFloat) -> PKStroke? {
        guard !s.points.isEmpty else { return nil }
        let c = s.color
        let ink: PKInk
        switch s.tool {
        case .pen: ink = PKInk(.pen, color: UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a))
        case .highlighter: ink = PKInk(.marker, color: UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1))
        case .pencil: ink = PKInk(.pencil, color: UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a))
        }
        // PencilKit zeichnet Stifte deutlich dünner als die nominelle Breite, GoodNotes eher kräftig.
        // Ohne Ausgleich ist die Schrift auf großen Seiten (z. B. A4-PDFs) praktisch unsichtbar.
        let width = s.tool == .highlighter ? s.width * scale : max(s.width * scale * 1.5, 1.8)
        var points = s.points
        // Ein einzelner Punkt (z. B. i-Punkt) braucht zwei Kontrollpunkte, damit PencilKit ihn zeichnet.
        if points.count == 1 { points.append(points[0]) }
        let controlPoints = points.enumerated().map { i, p in
            PKStrokePoint(location: CGPoint(x: p.x * scale, y: p.y * scale),
                          timeOffset: TimeInterval(i) * 0.008,
                          size: CGSize(width: width, height: width),
                          opacity: 1,
                          force: s.tool == .pencil ? p.force : 1,
                          azimuth: 0,
                          altitude: .pi / 2)
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: controlPoints, creationDate: Date()))
    }

    /// Ein PDF mit einer Seite je Notizbuchseite: Original-Vorlage (vektoriell) plus Umrissflächen.
    private static func backgroundPDF(_ document: GoodNotesDocument) -> Data {
        var sources: [String: PDFDocument] = [:]
        var images: [String: UIImage] = [:]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595.28, height: 841.89))
        return renderer.pdfData { ctx in
            for page in document.pages {
                let unit = GoodNotesDocument.pointsPerUnit
                let rect = CGRect(x: 0, y: 0, width: page.size.width * unit, height: page.size.height * unit)
                ctx.beginPage(withBounds: rect, pageInfo: [:])
                let cg = ctx.cgContext
                cg.setFillColor(UIColor.white.cgColor)
                cg.fill(rect)

                if let bg = page.background {
                    if sources[bg.attachmentPath] == nil, images[bg.attachmentPath] == nil,
                       let data = document.attachment(bg.attachmentPath) {
                        if let pdf = PDFDocument(data: data) { sources[bg.attachmentPath] = pdf }
                        else if let image = UIImage(data: data) { images[bg.attachmentPath] = image }
                    }
                    if let pdfPage = sources[bg.attachmentPath]?.page(at: bg.pdfPageIndex) {
                        PDFPageDrawing.draw(pdfPage, in: cg, size: rect.size)
                    } else if let image = images[bg.attachmentPath] {
                        image.draw(in: rect)
                    }
                }

                guard !page.fills.isEmpty else { continue }
                cg.saveGState()
                cg.scaleBy(x: unit, y: unit)
                for fill in page.fills {
                    let c = fill.color
                    cg.setFillColor(UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a).cgColor)
                    cg.addPath(fill.path)
                    cg.fillPath(using: .winding)
                }
                cg.restoreGState()
            }
        }
    }
}
