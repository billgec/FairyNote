import SwiftUI
import PencilKit

/// Zeichenfläche auf Basis von PencilKit. Speichert bei jeder Änderung in `drawingData`.
struct CanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        #if targetEnvironment(simulator)
        canvas.drawingPolicy = .anyInput // Simulator hat keinen Pencil
        #else
        canvas.drawingPolicy = .pencilOnly
        #endif
        canvas.isScrollEnabled = false
        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        canvas.delegate = context.coordinator

        let toolPicker = context.coordinator.toolPicker
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(true, forFirstResponder: canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        // Ein gemeinsamer Tool-Picker für alle Seiten, damit Stiftauswahl seitenübergreifend gilt.
        static let toolPicker = PKToolPicker()
        var toolPicker: PKToolPicker { Self.toolPicker }

        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}
