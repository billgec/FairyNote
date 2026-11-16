import Foundation

/// Liniatur einer Seite. Die Rohwerte werden gespeichert, also nie umbenennen.
enum PaperStyle: String, Codable, CaseIterable, Identifiable {
    case blank, lined, linedNarrow, grid, gridSmall, dotted, cornell, music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blanko"
        case .lined: "Liniert"
        case .linedNarrow: "Liniert eng"
        case .grid: "Kariert"
        case .gridSmall: "Kariert 5 mm"
        case .dotted: "Gepunktet"
        case .cornell: "Cornell"
        case .music: "Notenpapier"
        }
    }
}

/// Farbe des Papiers. `.theme` folgt dem App-Thema, alle anderen sind fest.
enum PaperColor: String, Codable, CaseIterable, Identifiable {
    case theme, white, eggshell, rose, mint, sky, grey, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: "Wie das Thema"
        case .white: "Weiß"
        case .eggshell: "Eierschale"
        case .rose: "Rosé"
        case .mint: "Minze"
        case .sky: "Himmel"
        case .grey: "Grau"
        case .dark: "Dunkel"
        }
    }

    /// Papier- und Linienfarbe als Hex.
    func hexes(for theme: AppTheme) -> (paper: String, line: String) {
        switch self {
        case .theme: (theme.paperHex, theme.lineHex)
        case .white: ("#FFFFFF", "#D1D1D1")
        case .eggshell: ("#F8F1DF", "#DDD0B0")
        case .rose: ("#FDEFF2", "#F0C5D0")
        case .mint: ("#EDF6EF", "#C2DCC8")
        case .sky: ("#EDF4FC", "#C3D6EE")
        case .grey: ("#EEEEEC", "#C9C9C5")
        case .dark: ("#25262B", "#474A54")
        }
    }

    /// Dunkles Papier: Striche werden dann hell angezeigt (PencilKit-Dunkelmodus).
    func isDark(for theme: AppTheme) -> Bool {
        !Theme.isLight(hexes(for: theme).paper)
    }
}

/// Fertige Kombinationen aus Liniatur und Papierfarbe für typische Notizbücher.
struct NotebookTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let style: PaperStyle
    let color: PaperColor

    static let all: [NotebookTemplate] = [
        NotebookTemplate(id: "vorlesung", name: "Vorlesung", style: .cornell, color: .eggshell),
        NotebookTemplate(id: "mathe", name: "Mathe", style: .gridSmall, color: .white),
        NotebookTemplate(id: "schreiben", name: "Schreiben", style: .lined, color: .eggshell),
        NotebookTemplate(id: "journal", name: "Journal", style: .dotted, color: .rose),
        NotebookTemplate(id: "skizzen", name: "Skizzen", style: .blank, color: .eggshell),
        NotebookTemplate(id: "planer", name: "Planer", style: .linedNarrow, color: .mint),
        NotebookTemplate(id: "nacht", name: "Lernabend", style: .dotted, color: .dark),
        NotebookTemplate(id: "musik", name: "Musik", style: .music, color: .white),
    ]
}
