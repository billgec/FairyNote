import SwiftUI
import UIKit
import CoreText

/// Design „Atelier“: Papierweiß, Tintenschwarz, ein kräftiges Koralle.
/// Titel in Instrument Serif, Oberfläche in der Systemschrift.
enum Theme {
    // MARK: Farben

    static let ink = Color(hex: "#141414")
    static let coral = Color(hex: "#FF5A3C")
    static let cobalt = Color(hex: "#2F5BEA")
    static let linen = Color(hex: "#E8E3DA")

    /// Hintergrund der Bibliothek / Werkzeugleiste.
    static let paper = dynamic(light: "#FFFFFF", dark: "#1A1918")
    /// Seitenleiste und Fläche hinter den Seiten.
    static let desk = dynamic(light: "#F2F0EC", dark: "#111111")
    /// Haarlinien.
    static let hairline = dynamic(light: "#EBE8E3", dark: "#2C2A28")

    /// Coverfarben mit Namen (Reihenfolge = Auswahl im Dialog).
    struct Cover: Hashable {
        let name: String
        let hex: String
        init(_ name: String, _ hex: String) { self.name = name; self.hex = hex }
    }

    static let covers: [Cover] = [
        Cover("Koralle", "#FF5A3C"),
        Cover("Tinte", "#141414"),
        Cover("Kobalt", "#2F5BEA"),
        Cover("Leinen", "#E8E3DA"),
        Cover("Senf", "#F2C94C"),
        Cover("Petrol", "#0F7B6C"),
        Cover("Pfirsich", "#FFB4A2"),
        Cover("Flieder", "#C9D4FF"),
    ]

    static func coverName(_ hex: String) -> String {
        covers.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? hex
    }

    /// Weiße oder schwarze Schrift, je nachdem was auf der Farbe besser lesbar ist.
    static func onColor(_ hex: String) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hex: hex).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? ink : .white
    }

    // MARK: Schrift

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size)
    }

    /// Einmal beim Start aufrufen: Schriften laden und Navigationsleiste anpassen.
    static func setUp() {
        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        if let large = UIFont(name: "InstrumentSerif-Regular", size: 44),
           let inline = UIFont(name: "InstrumentSerif-Regular", size: 24) {
            let bar = UINavigationBar.appearance()
            bar.largeTitleTextAttributes = [.font: large]
            bar.titleTextAttributes = [.font: inline]
        }
    }

    private static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}
