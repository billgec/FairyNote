import SwiftUI
import PencilKit

/// PKCanvasView mit eigenem UndoManager, damit Rückgängig pro Seite funktioniert.
final class PageCanvasView: PKCanvasView {
    private let pageUndoManager = UndoManager()
    override var undoManager: UndoManager? { pageUndoManager }
}

/// Zeichenfläche auf Basis von PencilKit. Meldet jede Änderung über `onChange`.
struct CanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    let tool: PKTool
    let toolSignature: String
    let fingerDrawing: Bool
    /// Auf dunklem Papier zeigt PencilKit die Striche im Dunkelmodus (dunkle Tinte wird hell).
    var darkPaper = false
    var onBegin: (PKCanvasView) -> Void = { _ in }
    var onChange: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PageCanvasView {
        let canvas = PageCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = darkPaper ? .dark : .light
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = fingerDrawing ? .anyInput : .pencilOnly
        canvas.tool = tool
        context.coordinator.appliedSignature = toolSignature
        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PageCanvasView, context: Context) {
        context.coordinator.parent = self
        let policy: PKCanvasViewDrawingPolicy = fingerDrawing ? .anyInput : .pencilOnly
        if canvas.drawingPolicy != policy { canvas.drawingPolicy = policy }
        let style: UIUserInterfaceStyle = darkPaper ? .dark : .light
        if canvas.overrideUserInterfaceStyle != style { canvas.overrideUserInterfaceStyle = style }
        if context.coordinator.appliedSignature != toolSignature {
            canvas.tool = tool
            context.coordinator.appliedSignature = toolSignature
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        var appliedSignature = ""

        init(_ parent: CanvasView) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            parent.onBegin(canvasView)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            guard data != parent.drawingData else { return }
            parent.drawingData = data
            parent.onChange()
        }
    }
}
