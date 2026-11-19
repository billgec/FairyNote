import SwiftUI
import PDFKit

/// Seitenhintergrund (Papiermuster oder PDF-Seite), gekachelt gezeichnet.
/// Dadurch bleibt er bei jedem Zoom scharf, ohne riesige Bitmaps im Speicher zu halten.
struct TiledPageBackground: UIViewRepresentable {
    enum Content {
        case paper(PaperStyle, paper: UIColor, line: UIColor)
        case pdf(PDFPage)
    }

    let content: Content

    func makeUIView(context: Context) -> TiledBackgroundView {
        let view = TiledBackgroundView()
        view.content = content
        return view
    }

    func updateUIView(_ view: TiledBackgroundView, context: Context) {
        view.content = content
    }
}

/// CATiledLayer ohne Einblend-Animation der Kacheln.
final class NoFadeTiledLayer: CATiledLayer {
    override class func fadeDuration() -> CFTimeInterval { 0 }
}

final class TiledBackgroundView: UIView {
    override class var layerClass: AnyClass { NoFadeTiledLayer.self }

    /// Wird auch von den Hintergrund-Threads des CATiledLayer gelesen, daher hinter einem Lock.
    private let lock = NSLock()
    private var _content: TiledPageBackground.Content?

    var content: TiledPageBackground.Content? {
        get { lock.withLock { _content } }
        set {
            guard !Self.same(newValue, content) else { return }
            lock.withLock { _content = newValue }
            switch newValue {
            case .paper(_, let paper, _): backgroundColor = paper
            default: backgroundColor = .white
            }
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        contentMode = .redraw
        let tiled = layer as! CATiledLayer
        tiled.tileSize = CGSize(width: 512, height: 512)
        tiled.levelsOfDetail = 1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht unterstützt") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Kacheln passend zur Bildschirmauflösung (der CATiledLayer rechnet sonst mit 1×).
        let scale = window?.screen.scale ?? 2
        if layer.contentsScale != scale { layer.contentsScale = scale }
    }

    // Läuft auf Hintergrund-Threads: nur `layer` und den Kontext verwenden.
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        let size = layer.bounds.size
        guard size.width > 0, let content else { return }
        switch content {
        case let .paper(style, paper, line):
            PaperPattern.draw(style, in: ctx, size: size, paper: paper, line: line)
        case let .pdf(page):
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(ctx.boundingBoxOfClipPath)
            PDFPageDrawing.draw(page, in: ctx, size: size)
        }
    }

    private static func same(_ a: TiledPageBackground.Content?, _ b: TiledPageBackground.Content?) -> Bool {
        switch (a, b) {
        case let (.paper(s1, p1, l1), .paper(s2, p2, l2)): s1 == s2 && p1 == p2 && l1 == l2
        case let (.pdf(x), .pdf(y)): x === y
        default: false
        }
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
