import Foundation
import SwiftData

@Model
final class Page {
    /// Gezeichnet wird immer in diesem festen Koordinatensystem (Breite in Punkten),
    /// die Anzeige skaliert es auf die verfügbare Breite. So passen Striche, PDF-Hintergrund und Export zusammen.
    static let canvasWidth: CGFloat = 900

    var index: Int = 0
    @Attribute(.externalStorage) var drawingData: Data?
    var recognizedText: String?
    var notebook: Notebook?
    /// Seite des importierten PDFs (`Notebook.backgroundPDF`), die als Hintergrund dient.
    var pdfPageIndex: Int?
    /// Seitengröße in PDF-Punkten (Standard: DIN A4).
    var width: Double = 595.28
    var height: Double = 841.89

    init(index: Int) {
        self.index = index
    }

    /// Breite / Höhe, für `aspectRatio`.
    var aspectRatio: CGFloat { width / height }

    var canvasSize: CGSize {
        CGSize(width: Self.canvasWidth, height: Self.canvasWidth * height / width)
    }
}
