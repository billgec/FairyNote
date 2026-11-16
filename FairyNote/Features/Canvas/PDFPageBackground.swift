import SwiftUI
import PDFKit

/// Zeigt eine PDF-Seite als (vektorscharfen) Seitenhintergrund.
struct PDFPageBackground: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFPageRenderView {
        let view = PDFPageRenderView()
        view.page = page
        return view
    }

    func updateUIView(_ view: PDFPageRenderView, context: Context) {
        if view.page !== page { view.page = page }
    }
}

final class PDFPageRenderView: UIView {
    var page: PDFPage? { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht unterstützt") }

    override func draw(_ rect: CGRect) {
        guard let page, let ctx = UIGraphicsGetCurrentContext() else { return }
        PDFPageDrawing.draw(page, in: ctx, size: bounds.size)
    }
}

enum PDFPageDrawing {
    /// Sichtbare Größe einer PDF-Seite in Punkten, Drehung berücksichtigt.
    static func size(of page: PDFPage) -> CGSize {
        let box = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
    }

    /// Zeichnet die Seite passend in ein Rechteck mit Ursprung oben links (UIKit-Koordinaten).
    static func draw(_ page: PDFPage, in ctx: CGContext, size: CGSize) {
        let pageSize = self.size(of: page)
        guard pageSize.width > 0 else { return }
        let scale = size.width / pageSize.width
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: scale, y: -scale)
        page.draw(with: .cropBox, to: ctx)
        ctx.restoreGState()
    }
}
