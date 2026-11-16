import SwiftUI

/// Zeichnet den Papierhintergrund relativ zur Seitenbreite, damit er bei jeder Größe gleich aussieht.
struct PaperBackground: View {
    let style: PaperStyle

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let spacing = size.width / 28
            let line = Color(red: 0.75, green: 0.8, blue: 0.9)

            switch style {
            case .blank:
                break
            case .lined:
                var path = Path()
                var y = spacing * 3
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
                ctx.stroke(path, with: .color(line), lineWidth: 0.7)
            case .grid:
                var path = Path()
                var x = spacing
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
                var y = spacing
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
                ctx.stroke(path, with: .color(line.opacity(0.7)), lineWidth: 0.5)
            case .dotted:
                let r: CGFloat = 1.2
                var y = spacing
                while y < size.height {
                    var x = spacing
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(line))
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
    }
}
