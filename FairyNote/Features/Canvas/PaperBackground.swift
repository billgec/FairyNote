import SwiftUI
import UIKit

/// Zeichnet den Papierhintergrund relativ zur Seitenbreite, damit er bei jeder Größe gleich aussieht.
struct PaperBackground: View {
    @Environment(\.theme) private var theme
    let style: PaperStyle
    var color: PaperColor = .theme

    var body: some View {
        let hexes = color.hexes(for: theme)
        let paper = UIColor(hex: hexes.paper)
        let line = UIColor(hex: hexes.line)
        Canvas { ctx, size in
            ctx.withCGContext { PaperPattern.draw(style, in: $0, size: size, paper: paper, line: line) }
        }
    }
}

/// Papiermuster als Core-Graphics-Zeichnung, gemeinsam für Anzeige und PDF-Export.
enum PaperPattern {
    static func draw(_ style: PaperStyle, color: PaperColor, theme: AppTheme, in ctx: CGContext, size: CGSize) {
        let hexes = color.hexes(for: theme)
        draw(style, in: ctx, size: size, paper: UIColor(hex: hexes.paper), line: UIColor(hex: hexes.line))
    }

    static func draw(_ style: PaperStyle, in ctx: CGContext, size: CGSize,
                     paper: UIColor = .white, line: UIColor = UIColor(white: 0.82, alpha: 1)) {
        ctx.saveGState()
        defer { ctx.restoreGState() }

        ctx.setFillColor(paper.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let w = size.width, h = size.height
        let spacing = w / 28 // ca. 7,5 mm auf A4
        // Linienstärken sind für die Seitenbreite `Page.canvasWidth` gedacht und skalieren mit.
        let unit = w / Page.canvasWidth

        func hLine(_ y: CGFloat, from x0: CGFloat = 0, to x1: CGFloat? = nil) {
            ctx.move(to: CGPoint(x: x0, y: y)); ctx.addLine(to: CGPoint(x: x1 ?? w, y: y))
        }
        func vLine(_ x: CGFloat, from y0: CGFloat = 0, to y1: CGFloat? = nil) {
            ctx.move(to: CGPoint(x: x, y: y0)); ctx.addLine(to: CGPoint(x: x, y: y1 ?? h))
        }
        func stroke(_ color: UIColor, _ width: CGFloat) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width * unit)
            ctx.strokePath()
        }
        func ruled(_ gap: CGFloat, from top: CGFloat, to bottom: CGFloat) {
            var y = top
            while y < bottom { hLine(y); y += gap }
        }
        func grid(_ gap: CGFloat) {
            var x = gap
            while x < w { vLine(x); x += gap }
            var y = gap
            while y < h { hLine(y); y += gap }
        }

        switch style {
        case .blank:
            break
        case .lined:
            ruled(spacing, from: spacing * 3, to: h)
            stroke(line, 0.7)
        case .linedNarrow:
            ruled(w / 38, from: spacing * 3, to: h)
            stroke(line, 0.6)
        case .grid:
            grid(spacing)
            stroke(line.withAlphaComponent(0.7), 0.5)
        case .gridSmall:
            grid(w / 42) // ca. 5 mm auf A4
            stroke(line.withAlphaComponent(0.6), 0.45)
        case .dotted:
            let r = 1.2 * unit
            ctx.setFillColor(line.cgColor)
            var y = spacing
            while y < h {
                var x = spacing
                while x < w {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    x += spacing
                }
                y += spacing
            }
        case .cornell:
            // Kopfzeile, Stichwortspalte links, Zusammenfassung unten.
            let header = spacing * 3
            let summary = h * 0.8
            let cue = w * 0.3
            ruled(spacing, from: header + spacing, to: summary - spacing / 2)
            stroke(line, 0.6)
            hLine(header); hLine(summary)
            vLine(cue, from: header, to: summary)
            stroke(line.stronger(), 1.4)
        case .music:
            let gap = w / 100
            let staff = gap * 4
            let top = spacing * 3, bottom = spacing * 2
            let count = max(1, Int((h - top - bottom) / (staff * 2.2)))
            let pitch = (h - top - bottom - staff) / CGFloat(max(count - 1, 1))
            let margin = spacing * 1.5
            for i in 0..<count {
                let y0 = top + CGFloat(i) * pitch
                for l in 0..<5 { hLine(y0 + CGFloat(l) * gap, from: margin, to: w - margin) }
                vLine(margin, from: y0, to: y0 + staff)
                vLine(w - margin, from: y0, to: y0 + staff)
            }
            stroke(line.stronger(), 0.7)
        }
    }
}

private extension UIColor {
    /// Etwas kräftigere Variante für Trennlinien (auf dunklem Papier heller).
    func stronger() -> UIColor {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let shifted = bri > 0.5 ? bri * 0.82 : min(bri * 1.35, 1)
        return UIColor(hue: hue, saturation: min(sat * 1.2, 1), brightness: shifted, alpha: alpha)
    }
}
