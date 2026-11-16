import SwiftUI
import UIKit

/// Zeichnet den Papierhintergrund relativ zur Seitenbreite, damit er bei jeder Größe gleich aussieht.
struct PaperBackground: View {
    let style: PaperStyle

    var body: some View {
        Canvas { ctx, size in
            ctx.withCGContext { PaperPattern.draw(style, in: $0, size: size) }
        }
    }
}

/// Papiermuster als Core-Graphics-Zeichnung, gemeinsam für Anzeige und PDF-Export.
enum PaperPattern {
    static func draw(_ style: PaperStyle, in ctx: CGContext, size: CGSize) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let spacing = size.width / 28
        // Linienstärken sind für die Seitenbreite `Page.canvasWidth` gedacht und skalieren mit.
        let unit = size.width / Page.canvasWidth
        let line = UIColor(white: 0.82, alpha: 1)

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
