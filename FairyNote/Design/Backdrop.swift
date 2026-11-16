import SwiftUI

/// Dezenter Hintergrund je Thema: Herzchen, Pünktchen-Wiese oder Sternenhimmel.
struct Backdrop: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.background
            switch theme.coverStyle {
            case .sticker:
                pattern(symbol: theme.motif, count: 26, opacity: 0.10)
            case .foil:
                LinearGradient(colors: [Color(hex: "#232A6E").opacity(0.6), .clear],
                               startPoint: .top, endPoint: .center)
                stars
            case .initial:
                EmptyView()
            }
        }
        .ignoresSafeArea()
    }

    /// Verstreute kleine Symbole an festen (zufällig wirkenden) Positionen.
    private func pattern(symbol: String, count: Int, opacity: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            var image = ctx.resolve(Image(systemName: symbol))
            image.shading = .color(theme.accent)
            for _ in 0..<count {
                let x = rng.next() * size.width
                let y = rng.next() * size.height
                let s = 10 + rng.next() * 12
                var c = ctx
                c.opacity = opacity
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(rng.next() * 60 - 30))
                c.draw(image, in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
            }
        }
        .allowsHitTesting(false)
    }

    private var stars: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 3)
            for _ in 0..<70 {
                let x = rng.next() * size.width
                let y = rng.next() * size.height
                let r = 0.6 + rng.next() * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(0.25 + rng.next() * 0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Kleiner deterministischer Zufallsgenerator, damit das Muster nicht bei jedem Neuzeichnen springt.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }

    /// Zahl zwischen 0 und 1.
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 10_000) / 10_000
    }
}
