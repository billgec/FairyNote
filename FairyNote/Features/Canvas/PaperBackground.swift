import SwiftUI
import UIKit

/// Zeichnet den Papierhintergrund relativ zur Seitenbreite, damit er bei jeder Größe gleich aussieht.
struct PaperBackground: View {
    @Environment(\.theme) private var theme
    let style: PaperStyle

    var body: some View {
        let paper = UIColor(hex: theme.paperHex)
        let line = UIColor(hex: theme.lineHex)
        Canvas { ctx, size in
            ctx.withCGContext { PaperPattern.draw(style, in: $0, size: size, paper: paper, line: line) }
        }
    }
}

/// Papiermuster als Core-Graphics-Zeichnung, gemeinsam für Anzeige und PDF-Export.
enum PaperPattern {
    /// Standardfarben (weißes Papier, graue Linien) für den Export, im Editor kommen sie vom Thema.
    static func draw(_ style: PaperStyle, in ctx: CGContext, size: CGSize,
                     paper: UIColor = .white, line: UIColor = UIColor(white: 0.82, alpha: 1)) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        ctx.setFillColor(paper.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let spacing = size.width / 28
        // Linienstärken sind für die Seitenbreite `Page.canvasWidth` gedacht und skalieren mit.
        let unit = size.width / Page.canvasWidth

        switch style {
        case .blank:
            break
        case .lined:
            var y = spacing * 3
            while y < size.height {
                ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: size.width, y: y)); y += spacing
            }
            ctx.setStrokeColor(line.cgColor)
            ctx.setLineWidth(0.7 * unit)
            ctx.strokePath()
        case .grid:
            var x = spacing
            while x < size.width {
                ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: size.height)); x += spacing
            }
            var y = spacing
            while y < size.height {
                ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: size.width, y: y)); y += spacing
            }
            ctx.setStrokeColor(line.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(0.5 * unit)
            ctx.strokePath()
        case .dotted:
            let r = 1.2 * unit
            ctx.setFillColor(line.cgColor)
            var y = spacing
            while y < size.height {
                var x = spacing
                while x < size.width {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
