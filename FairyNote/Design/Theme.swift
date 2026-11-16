import SwiftUI
import UIKit
import CoreText

/// Ein Farb- und Schriftthema der App. Auswahl in den Einstellungen, gespeichert unter `AppTheme.storageKey`.
struct AppTheme: Identifiable, Equatable {
    struct Cover: Hashable {
        let name: String
        let hex: String
        init(_ name: String, _ hex: String) { self.name = name; self.hex = hex }
    }

    enum CoverStyle { case sticker, foil, initial }
    enum TitleFont { case rounded, serif, instrumentSerif }

    let id: String
    let name: String
    let tagline: String
    let scheme: ColorScheme

    // Farben (Hex, damit sie auch für UIKit/PencilKit nutzbar sind)
    let accentHex: String
    let backgroundHex: String
    let surfaceHex: String
    let sidebarHex: String
    let deskHex: String
    let hairlineHex: String
    let inkHex: String
    let secondaryHex: String
    let paperHex: String
    let lineHex: String

    let covers: [Cover]
    let coverStyle: CoverStyle
    let titleFont: TitleFont
    let coverRadius: CGFloat
    /// Kleines Symbol, das im Thema immer wieder auftaucht (Begrüßung, leere Ansicht).
    let motif: String
    /// Sticker auf den Covern (nur `CoverStyle.sticker`).
    let stickers: [String]

    var accent: Color { Color(hex: accentHex) }
    var background: Color { Color(hex: backgroundHex) }
    var surface: Color { Color(hex: surfaceHex) }
    var sidebar: Color { Color(hex: sidebarHex) }
    var desk: Color { Color(hex: deskHex) }
    var hairline: Color { Color(hex: hairlineHex) }
    var ink: Color { Color(hex: inkHex) }
    var secondaryInk: Color { Color(hex: secondaryHex) }

    func title(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        switch titleFont {
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .serif: .system(size: size, weight: weight == .bold ? .semibold : weight, design: .serif)
        case .instrumentSerif: .custom("InstrumentSerif-Regular", size: size * 1.15)
        }
    }

    /// Coverfarben sind „Plätze“: Ein Notizbuch mit Platz 3 bekommt in jedem Thema dessen dritte Farbe.
    func coverHex(for stored: String) -> String {
        for theme in Self.all {
            if let i = theme.covers.firstIndex(where: { $0.hex.caseInsensitiveCompare(stored) == .orderedSame }) {
                return covers[i % covers.count].hex
            }
        }
        return stored
    }

    static func == (a: AppTheme, b: AppTheme) -> Bool { a.id == b.id }
}

// MARK: - Themen

extension AppTheme {
    static let storageKey = "theme"
    static let nameKey = "userName"

    static let kirschbluete = AppTheme(
        id: "kirschbluete", name: "Kirschblüte", tagline: "Rosa, verspielt und ganz weich",
        scheme: .light,
        accentHex: "#EE6F94", backgroundHex: "#FFF7F8", surfaceHex: "#FFFFFF", sidebarHex: "#FDEBEF",
        deskHex: "#FBEEF1", hairlineHex: "#F3D9DF", inkHex: "#4A2E3A", secondaryHex: "#A07D8A",
        paperHex: "#FFFDFC", lineHex: "#F4CBD5",
        covers: [Cover("Rosa", "#F7B6C8"), Cover("Erdbeere", "#F28AA6"), Cover("Pfirsich", "#FFCFB3"),
                 Cover("Vanille", "#FCE7A8"), Cover("Minze", "#BFE6D3"), Cover("Himmel", "#BBD8F5"),
                 Cover("Lavendel", "#D8C8F2"), Cover("Pflaume", "#B07A98")],
        coverStyle: .sticker, titleFont: .rounded, coverRadius: 14, motif: "heart.fill",
        stickers: ["heart.fill", "star.fill", "sparkles", "cloud.fill", "sun.max.fill", "camera.macro", "moon.fill", "leaf.fill"])

    static let wiesenbluete = AppTheme(
        id: "wiesenbluete", name: "Wiesenblüte", tagline: "Salbei, Creme und Blumenwiese",
        scheme: .light,
        accentHex: "#5E8C70", backgroundHex: "#FAFAF4", surfaceHex: "#FFFFFF", sidebarHex: "#EAF0E4",
        deskHex: "#EEF1E8", hairlineHex: "#DCE4D5", inkHex: "#2F3A33", secondaryHex: "#78857C",
        paperHex: "#FFFEFA", lineHex: "#CCDACB",
        covers: [Cover("Salbei", "#A9C9B3"), Cover("Kirschblüte", "#F7BEC8"), Cover("Butterblume", "#F6D48A"),
                 Cover("Himmelblau", "#A9C4E8"), Cover("Flieder", "#D9C9EE"), Cover("Moos", "#7FA58C"),
                 Cover("Aprikose", "#F6C3A0"), Cover("Nebel", "#CFDCDC")],
        coverStyle: .sticker, titleFont: .rounded, coverRadius: 16, motif: "leaf.fill",
        stickers: ["leaf.fill", "camera.macro", "ladybug.fill", "sun.max.fill", "cloud.fill", "bird.fill", "tree.fill", "drop.fill"])

    static let mondlicht = AppTheme(
        id: "mondlicht", name: "Mondlicht", tagline: "Nachtblau und Gold, für Lernabende",
        scheme: .dark,
        accentHex: "#F2C14E", backgroundHex: "#161A42", surfaceHex: "#21265A", sidebarHex: "#10132F",
        deskHex: "#0E1029", hairlineHex: "#2E3474", inkHex: "#F3E9D2", secondaryHex: "#A9A6C9",
        paperHex: "#FBF6EA", lineHex: "#DCD1B8",
        covers: [Cover("Mitternacht", "#2A2F6B"), Cover("Beere", "#7B2F4A"), Cover("Tanne", "#2C5A52"),
                 Cover("Indigo", "#3B3F8F"), Cover("Amethyst", "#5B3A7A"), Cover("Bernstein", "#8A5A2B"),
                 Cover("Schiefer", "#2F3D5C"), Cover("Pflaume", "#4A2448")],
        coverStyle: .foil, titleFont: .serif, coverRadius: 8, motif: "moon.stars.fill", stickers: [])

    static let atelier = AppTheme(
        id: "atelier", name: "Atelier", tagline: "Klar, ruhig, wie ein Magazin",
        scheme: .light,
        accentHex: "#FF5A3C", backgroundHex: "#FFFFFF", surfaceHex: "#FFFFFF", sidebarHex: "#F6F5F2",
        deskHex: "#F2F0EC", hairlineHex: "#EBE8E3", inkHex: "#141414", secondaryHex: "#7A7672",
        paperHex: "#FFFFFF", lineHex: "#D1D1D1",
        covers: [Cover("Koralle", "#FF5A3C"), Cover("Tinte", "#141414"), Cover("Kobalt", "#2F5BEA"),
                 Cover("Leinen", "#E8E3DA"), Cover("Senf", "#F2C94C"), Cover("Petrol", "#0F7B6C"),
                 Cover("Pfirsich", "#FFB4A2"), Cover("Flieder", "#C9D4FF")],
        coverStyle: .initial, titleFont: .instrumentSerif, coverRadius: 3, motif: "asterisk", stickers: [])

    static let all: [AppTheme] = [kirschbluete, wiesenbluete, mondlicht, atelier]
    static let standard = kirschbluete

    static func named(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? standard
    }

    /// Aktuelles Thema außerhalb von Views (z. B. beim Import).
    static var current: AppTheme {
        named(UserDefaults.standard.string(forKey: storageKey) ?? standard.id)
    }
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.standard
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Hilfen

enum Theme {
    /// Weiße oder dunkle Schrift, je nachdem was auf der Farbe besser lesbar ist.
    static func onColor(_ hex: String) -> Color {
        isLight(hex) ? Color(hex: "#3A2A33") : .white
    }

    static func isLight(_ hex: String) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hex: hex).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6
    }

    /// Einmal beim Start aufrufen: mitgelieferte Schriften laden.
    static func setUp() {
        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Begrüßung je nach Tageszeit.
    static func greeting(name: String, at date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let base: String = switch hour {
        case 5..<11: "Guten Morgen"
        case 11..<17: "Hallo"
        case 17..<22: "Guten Abend"
        default: "Gute Nacht"
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? base : "\(base), \(trimmed)"
    }
}
