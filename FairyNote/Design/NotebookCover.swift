import SwiftUI
import UIKit

/// Notizbuch-Cover mit etwas Tiefe: Buchrücken, Seitenkanten, Glanz und weicher Schatten.
/// Die Verzierung hängt vom Thema ab (Sticker, Goldprägung oder großes Initial).
struct NotebookCover: View {
    @Environment(\.theme) private var theme
    let notebook: Notebook

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CoverArt(title: notebook.title,
                     hex: theme.coverHex(for: notebook.coverColorHex),
                     seed: Int(notebook.createdAt.timeIntervalSince1970))
                .padding(.bottom, 8)
            Text(notebook.title)
                .font(theme.title(15, weight: .semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Text(notebook.modifiedAt, style: .date)
                .font(.caption)
                .foregroundStyle(theme.secondaryInk)
        }
        .contentShape(Rectangle())
    }
}

/// Nur das Cover, auch für Vorschauen in den Einstellungen.
struct CoverArt: View {
    @Environment(\.theme) private var theme
    let title: String
    let hex: String
    var seed: Int = 0

    var body: some View {
        let radius = theme.coverRadius
        let shape = UnevenRoundedRectangle(topLeadingRadius: min(radius, 4), bottomLeadingRadius: min(radius, 4),
                                           bottomTrailingRadius: radius, topTrailingRadius: radius)
        ZStack {
            // Seitenkanten hinter dem Cover → wirkt wie ein dickes Buch.
            shape.fill(Color(hex: theme.paperHex))
                .overlay(shape.stroke(.black.opacity(0.08), lineWidth: 1))
                .offset(x: 5, y: 3)
            shape.fill(Color(hex: theme.paperHex))
                .overlay(shape.stroke(.black.opacity(0.06), lineWidth: 1))
                .offset(x: 2.5, y: 1.5)

            shape.fill(Color(hex: hex))
                .overlay {
                    // Weicher Glanz von oben links.
                    shape.fill(LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.06)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay(alignment: .leading) {
                    // Buchrücken
                    HStack(spacing: 0) {
                        Rectangle().fill(.black.opacity(0.14)).frame(width: 9)
                        Rectangle().fill(.white.opacity(0.18)).frame(width: 1.5)
                    }
                }
                .overlay { decoration }
                .clipShape(shape)
        }
        .aspectRatio(0.75, contentMode: .fit)
        .compositingGroup()
        .shadow(color: .black.opacity(theme.scheme == .dark ? 0.35 : 0.08), radius: 2, y: 1)
        .shadow(color: .black.opacity(theme.scheme == .dark ? 0.45 : 0.12), radius: 12, y: 8)
    }

    private var fg: Color { Theme.onColor(hex) }

    /// Farbe um `amount` abdunkeln (iOS 17 kennt `Color.mix` noch nicht).
    private func shade(_ hex: String, _ amount: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hex: hex).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount))
    }

    @ViewBuilder
    private var decoration: some View {
        switch theme.coverStyle {
        case .sticker: sticker
        case .foil: foil
        case .initial: initial
        }
    }

    // Kirschblüte / Wiesenblüte: Gummiband, runder Sticker, Titel-Etikett.
    private var sticker: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Rectangle()
                    .fill(shade(hex, 0.25))
                    .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.2)).frame(width: 1) }
                    .frame(width: w * 0.045, height: geo.size.height)
                    .position(x: w * 0.84, y: geo.size.height / 2)

                let symbol = theme.stickers.isEmpty ? theme.motif : theme.stickers[abs(seed) % theme.stickers.count]
                Circle()
                    .fill(.white)
                    .frame(width: w * 0.36, height: w * 0.36)
                    .overlay(Circle().strokeBorder(Color(hex: hex).opacity(0.5), lineWidth: 2).padding(4))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: w * 0.15, weight: .semibold))
                            .foregroundStyle(shade(hex, 0.2))
                    }
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                    .rotationEffect(.degrees(Double(seed % 15) - 7))
                    .position(x: w * 0.47, y: geo.size.height * 0.36)

                Text(title)
                    .font(theme.title(max(9, w * 0.07), weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white, in: Capsule())
                    .frame(maxWidth: w * 0.7)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .position(x: w * 0.47, y: geo.size.height * 0.76)
            }
        }
    }

    // Mondlicht: Goldrahmen, Mond mit Stern, Titel in Serifenschrift.
    private var foil: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let gold = Color(hex: "#F2C14E")
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(gold.opacity(0.6), lineWidth: 1)
                    .padding(.vertical, w * 0.1)
                    .padding(.leading, w * 0.16)
                    .padding(.trailing, w * 0.09)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: w * 0.2))
                    .foregroundStyle(gold)
                    .shadow(color: gold.opacity(0.6), radius: 6)
                    .position(x: w * 0.54, y: geo.size.height * 0.36)
                Text(title)
                    .font(.system(size: max(10, w * 0.08), weight: .medium, design: .serif))
                    .foregroundStyle(Color(hex: "#F5E6C4"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: w * 0.62)
                    .position(x: w * 0.54, y: geo.size.height * 0.72)
            }
        }
    }

    // Atelier: großes Initial und Titel in Versalien.
    private var initial: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Text(title.prefix(1).uppercased())
                    .font(.custom("InstrumentSerif-Regular", size: w * 0.6))
                    .foregroundStyle(fg)
                    .padding(.leading, w * 0.14)
                    .offset(y: -w * 0.04)
                Text(title.uppercased())
                    .font(.system(size: max(8, w * 0.06), weight: .medium))
                    .tracking(1.2)
                    .lineLimit(2)
                    .foregroundStyle(fg.opacity(0.85))
                    .padding(.leading, w * 0.14)
                    .padding(.trailing, 10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, w * 0.09)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

/// Leichtes Eindrücken beim Antippen.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
