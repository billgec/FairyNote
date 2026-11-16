import Foundation

enum PaperStyle: String, Codable, CaseIterable, Identifiable {
    case blank, lined, grid, dotted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blanko"
        case .lined: "Liniert"
        case .grid: "Kariert"
        case .dotted: "Gepunktet"
        }
    }
}
