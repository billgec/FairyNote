import SwiftUI
import PencilKit

/// PKCanvasView mit eigenem UndoManager, damit Rückgängig pro Seite funktioniert.
/// Die Ansicht wird über `zoomScale` auf die Anzeigegröße gebracht, so bleibt die Tinte auch gezoomt scharf.
final class PageCanvasView: PKCanvasView {
    private let pageUndoManager = UndoManager()
    override var undoManager: UndoManager? { pageUndoManager }

    /// Anzeigebreite / `Page.canvasWidth`.
    var pageScale: CGFloat = 1 {
        didSet { if pageScale != oldValue { setNeedsLayout() } }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard pageScale > 0 else { return }
        if abs(zoomScale - pageScale) > 0.0001 {
            minimumZoomScale = min(minimumZoomScale, pageScale)
            maximumZoomScale = max(maximumZoomScale, pageScale)
            zoomScale = pageScale
        }
        let size = CGSize(width: bounds.width, height: bounds.height)
        if contentSize != size { contentSize = size }
        if contentOffset != .zero { contentOffset = .zero }
    }
}

/// Zeichenfläche auf Basis von PencilKit. Meldet jede Änderung über `onChange`.
struct CanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    let tool: PKTool
    let toolSignature: String
    let fingerDrawing: Bool
    /// Anzeigebreite / `Page.canvasWidth`.
    var scale: CGFloat = 1
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
        canvas.bouncesZoom = false
        canvas.minimumZoomScale = 0.1
        canvas.maximumZoomScale = 8
        // Gezoomt wird die ganze Seitenansicht, nicht die einzelne Zeichenfläche.
        canvas.pinchGestureRecognizer?.isEnabled = false
        canvas.pageScale = scale
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
        canvas.pageScale = scale
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
