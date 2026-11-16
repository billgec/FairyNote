import SwiftUI
import PencilKit
import Observation

/// Gemeinsamer Werkzeugzustand für alle Seiten eines Fensters.
/// Merkt sich Auswahl, Farben und Stärken in UserDefaults, damit sie einen Neustart überstehen.
@Observable
final class ToolState {
    enum Kind: String, CaseIterable, Identifiable {
        case pen, marker, eraser, lasso
        var id: String { rawValue }

        var title: String {
            switch self {
            case .pen: "Stift"
            case .marker: "Marker"
            case .eraser: "Radierer"
            case .lasso: "Lasso"
            }
        }

        var symbol: String {
            switch self {
            case .pen: "pencil.tip"
            case .marker: "highlighter"
            case .eraser: "eraser"
            case .lasso: "lasso"
            }
        }
    }

    enum EraserMode: String { case stroke, pixel }

    static let penColors = ["#1C1C1E", "#2B4FC2", "#D23B3B", "#2E8B57", "#7A5CFA", "#F08A24"]
    static let markerColors = ["#FFE14D", "#9BE564", "#FF8FC7", "#7CC7FF", "#FFB25B"]
    static let penWidths: [CGFloat] = [1.5, 3, 6]
    static let markerWidths: [CGFloat] = [10, 18, 28]
    static let eraserWidths: [CGFloat] = [8, 20, 40]

    var kind: Kind { didSet { store("kind", kind.rawValue) } }
    var penColorHex: String { didSet { store("penColor", penColorHex) } }
    var markerColorHex: String { didSet { store("markerColor", markerColorHex) } }
    var penWidth: CGFloat { didSet { store("penWidth", Double(penWidth)) } }
    var markerWidth: CGFloat { didSet { store("markerWidth", Double(markerWidth)) } }
    var eraserWidth: CGFloat { didSet { store("eraserWidth", Double(eraserWidth)) } }
    var eraserMode: EraserMode { didSet { store("eraserMode", eraserMode.rawValue) } }
    /// Aus: nur der Pencil zeichnet, Finger scrollt. An: auch der Finger zeichnet.
    var fingerDrawing: Bool { didSet { store("fingerDrawing", fingerDrawing) } }

    /// Zuletzt benutzte Seite, auf die Rückgängig/Wiederholen wirken.
    @ObservationIgnored weak var activeCanvas: PKCanvasView?

    init() {
        let d = UserDefaults.standard
        kind = Kind(rawValue: d.string(forKey: Self.key("kind")) ?? "") ?? .pen
        penColorHex = d.string(forKey: Self.key("penColor")) ?? Self.penColors[0]
        markerColorHex = d.string(forKey: Self.key("markerColor")) ?? Self.markerColors[0]
        penWidth = CGFloat(d.object(forKey: Self.key("penWidth")) as? Double ?? Double(Self.penWidths[1]))
        markerWidth = CGFloat(d.object(forKey: Self.key("markerWidth")) as? Double ?? Double(Self.markerWidths[1]))
        eraserWidth = CGFloat(d.object(forKey: Self.key("eraserWidth")) as? Double ?? Double(Self.eraserWidths[1]))
        eraserMode = EraserMode(rawValue: d.string(forKey: Self.key("eraserMode")) ?? "") ?? .stroke
        #if targetEnvironment(simulator)
        fingerDrawing = true // Simulator hat keinen Pencil
        #else
        fingerDrawing = d.bool(forKey: Self.key("fingerDrawing"))
        #endif
    }

    // MARK: Werkzeug für PencilKit

    var pkTool: PKTool {
        switch kind {
        case .pen:
            return PKInkingTool(.pen, color: UIColor(hex: penColorHex), width: penWidth)
        case .marker:
            return PKInkingTool(.marker, color: UIColor(hex: markerColorHex), width: markerWidth)
        case .eraser:
            return eraserMode == .stroke
                ? PKEraserTool(.vector)
                : PKEraserTool(.bitmap, width: eraserWidth)
        case .lasso:
            return PKLassoTool()
        }
    }

    /// Kurzer Schlüssel, an dem eine Seite erkennt, ob sich das Werkzeug geändert hat.
    var signature: String {
        "\(kind.rawValue)|\(penColorHex)|\(markerColorHex)|\(penWidth)|\(markerWidth)|\(eraserWidth)|\(eraserMode.rawValue)"
    }

    // MARK: Farbe/Stärke des aktuellen Werkzeugs

    var colors: [String] {
        kind == .marker ? Self.markerColors : Self.penColors
    }

    var colorHex: String {
        get { kind == .marker ? markerColorHex : penColorHex }
        set { if kind == .marker { markerColorHex = newValue } else { penColorHex = newValue } }
    }

    var widths: [CGFloat] {
        switch kind {
        case .pen: Self.penWidths
        case .marker: Self.markerWidths
        case .eraser: eraserMode == .pixel ? Self.eraserWidths : []
        case .lasso: []
        }
    }

    var width: CGFloat {
        get {
            switch kind {
            case .marker: markerWidth
            case .eraser: eraserWidth
            default: penWidth
            }
        }
        set {
            switch kind {
            case .pen: penWidth = newValue
            case .marker: markerWidth = newValue
            case .eraser: eraserWidth = newValue
            case .lasso: break
            }
        }
    }

    // MARK: Rückgängig

    func undo() { activeCanvas?.undoManager?.undo() }
    func redo() { activeCanvas?.undoManager?.redo() }

    // MARK: Speichern

    private static func key(_ name: String) -> String { "tool.\(name)" }
    private func store(_ name: String, _ value: Any) {
        UserDefaults.standard.set(value, forKey: Self.key(name))
    }
}
