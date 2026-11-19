import SwiftUI
import UIKit
import Observation

/// Zoom und Drehung der Seitenansicht.
/// Zwei Finger zoomen und drehen, ein Finger scrollt, der Pencil zeichnet unverändert weiter.
///
/// Während die Finger auf dem Display liegen, wird nur optisch skaliert/gedreht (flüssig).
/// Beim Loslassen wird der Zoom ins Layout übernommen, damit Papier, PDF und Tinte wieder scharf gezeichnet werden.
@Observable
final class PageViewport {
    static let zoomRange: ClosedRange<CGFloat> = 0.5...3
    static let pagePadding: CGFloat = 32
    static let pageSpacing: CGFloat = 20

    /// Übernommener Zoom: bestimmt die Seitenbreite im Layout.
    private(set) var zoom: CGFloat = 1
    /// Übernommene Drehung.
    private(set) var rotation: Angle = .zero
    /// Zoom/Drehung, solange die Finger noch auf dem Display liegen (nur optisch).
    private(set) var liveScale: CGFloat = 1
    private(set) var liveRotation: Angle = .zero
    /// Pinch-Mittelpunkt im Sichtbereich der (gedrehten) ScrollView.
    private var pinchAnchor: CGPoint = .zero

    /// Geometrie des sichtbaren Bereichs, wird von der NotebookView gesetzt.
    @ObservationIgnored var layout = ViewportLayout(size: .zero)
    @ObservationIgnored private let gestures = ViewportGestures()

    init() { gestures.viewport = self }

    var isTransformed: Bool { zoom != 1 || rotation != .zero }
    var displayRotation: Angle { rotation + liveRotation }

    /// Bezugspunkt für die optische Skalierung, relativ zum (ungedrehten) ScrollView-Rahmen.
    var scaleAnchor: UnitPoint {
        let d = layout.diagonal
        guard d > 0 else { return .center }
        let p = layout.screenPoint(for: pinchAnchor, rotation: displayRotation)
        return UnitPoint(x: (p.x + layout.margin.width) / d, y: (p.y + layout.margin.height) / d)
    }

    func attach(to scrollView: UIScrollView) { gestures.attach(to: scrollView) }
    func detach() { gestures.detach() }

    /// Zurück auf 100 % und gerade, die Bildschirmmitte bleibt stehen.
    func reset() {
        let d = layout.diagonal
        commitZoom(to: 1, anchor: CGPoint(x: d / 2, y: d / 2))
        withAnimation(.snappy) { rotation = .zero }
    }

    // MARK: Gesten

    fileprivate func pinchBegan(anchor: CGPoint) {
        pinchAnchor = anchor
    }

    fileprivate func pinchChanged(scale: CGFloat) {
        let target = (zoom * scale).clamped(to: Self.zoomRange)
        liveScale = target / zoom
    }

    fileprivate func pinchEnded() {
        commitZoom(to: zoom * liveScale, anchor: pinchAnchor)
    }

    fileprivate func rotationChanged(_ angle: Angle) {
        liveRotation = angle
    }

    fileprivate func rotationEnded() {
        var total = (rotation + liveRotation).degrees.truncatingRemainder(dividingBy: 360)
        if total > 180 { total -= 360 }
        if total <= -180 { total += 360 }
        // In der Nähe von 0°, 90°, 180° … einrasten.
        let nearest = (total / 90).rounded() * 90
        if abs(total - nearest) < 6 { total = nearest == -180 ? 180 : nearest }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            rotation = .degrees(total)
            liveRotation = .zero
        }
    }

    // MARK: Zoom übernehmen

    /// Setzt den Layout-Zoom und verschiebt den Scrollbereich so, dass der Inhalt unter `anchor` stehen bleibt.
    private func commitZoom(to target: CGFloat, anchor: CGPoint) {
        let newZoom = target.clamped(to: Self.zoomRange)
        let oldZoom = zoom
        guard let scrollView = gestures.scrollView else {
            zoom = newZoom
            liveScale = 1
            return
        }
        let layout = self.layout
        // Inhaltspunkt unter dem Anker, in zoomunabhängige Einheiten umgerechnet.
        let content = CGPoint(x: scrollView.contentOffset.x + anchor.x, y: scrollView.contentOffset.y + anchor.y)
        let unit = CGPoint(x: (content.x - layout.contentOrigin(zoom: oldZoom).x) / oldZoom,
                           y: (content.y - layout.contentOrigin(zoom: oldZoom).y) / oldZoom)

        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            zoom = newZoom
            liveScale = 1
        }

        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView else { return }
            scrollView.superview?.layoutIfNeeded()
            let origin = layout.contentOrigin(zoom: newZoom)
            let inset = scrollView.adjustedContentInset
            let maxX = max(-inset.left, scrollView.contentSize.width - scrollView.bounds.width + inset.right)
            let maxY = max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
            let x = (origin.x + unit.x * newZoom - anchor.x).clamped(to: -inset.left...maxX)
            let y = (origin.y + unit.y * newZoom - anchor.y).clamped(to: -inset.top...maxY)
            scrollView.setContentOffset(CGPoint(x: x, y: y), animated: false)
        }
    }
}

/// Maße des Sichtbereichs. Die ScrollView ist ein Quadrat mit der Bildschirmdiagonale,
/// damit sie den sichtbaren Bereich in jeder Drehung vollständig abdeckt.
struct ViewportLayout: Equatable {
    var size: CGSize

    var diagonal: CGFloat { (size.width * size.width + size.height * size.height).squareRoot().rounded(.up) }

    /// Teil der ScrollView, der in ungedrehtem Zustand außerhalb des Bildschirms liegt.
    var margin: CGSize { CGSize(width: (diagonal - size.width) / 2, height: (diagonal - size.height) / 2) }

    /// Seitenbreite bei 100 %.
    var baseWidth: CGFloat {
        max(240, min(size.width - 2 * PageViewport.pagePadding, Page.canvasWidth))
    }

    /// Position der Seitenspalte (inkl. Innenabstand) im Scrollinhalt.
    func contentOrigin(zoom: CGFloat) -> CGPoint {
        let inner = (baseWidth + 2 * PageViewport.pagePadding) * zoom
        let total = max(diagonal, inner + 2 * margin.width)
        return CGPoint(x: (total - inner) / 2, y: margin.height)
    }

    /// Bildschirmpunkt (im ungedrehten Sichtbereich) zu einem Punkt im ScrollView-Sichtbereich.
    func screenPoint(for viewportPoint: CGPoint, rotation: Angle) -> CGPoint {
        let half = diagonal / 2
        let dx = viewportPoint.x - half, dy = viewportPoint.y - half
        let c = cos(rotation.radians), s = sin(rotation.radians)
        return CGPoint(x: size.width / 2 + dx * c - dy * s, y: size.height / 2 + dx * s + dy * c)
    }
}

/// UIKit-Gesten für Zoom und Drehung. Sie hängen am Fenster (nicht an der gedrehten ScrollView),
/// damit die optische Drehung/Skalierung die Messung nicht verfälscht. Nur Fingerberührungen zählen.
private final class ViewportGestures: NSObject, UIGestureRecognizerDelegate {
    weak var viewport: PageViewport?
    private(set) weak var scrollView: UIScrollView?
    private weak var host: UIView?
    private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
    private lazy var rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate))
    private var rotationStarted = false
    private var rotationOffset: CGFloat = 0
    /// Erst ab dieser Drehung (≈ 8°) wird gedreht, damit normales Zoomen nicht wackelt.
    private let rotationThreshold: CGFloat = 0.14

    func attach(to scrollView: UIScrollView) {
        guard let window = scrollView.window else { return }
        self.scrollView = scrollView
        guard host !== window else { return }
        detach()
        for recognizer in [pinch, rotate] as [UIGestureRecognizer] {
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            window.addGestureRecognizer(recognizer)
        }
        host = window
    }

    func detach() {
        host?.removeGestureRecognizer(pinch)
        host?.removeGestureRecognizer(rotate)
        host = nil
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let viewport, let scrollView else { return }
        switch recognizer.state {
        case .began:
            let p = recognizer.location(in: scrollView)
            viewport.pinchBegan(anchor: CGPoint(x: p.x - scrollView.contentOffset.x, y: p.y - scrollView.contentOffset.y))
            viewport.pinchChanged(scale: recognizer.scale)
        case .changed:
            viewport.pinchChanged(scale: recognizer.scale)
        case .ended, .cancelled, .failed:
            viewport.pinchEnded()
        default:
            break
        }
    }

    @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
        guard let viewport else { return }
        switch recognizer.state {
        case .began, .changed:
            if !rotationStarted {
                guard abs(recognizer.rotation) > rotationThreshold else { return }
                rotationStarted = true
                rotationOffset = recognizer.rotation
            }
            viewport.rotationChanged(.radians(Double(recognizer.rotation - rotationOffset)))
        case .ended, .cancelled, .failed:
            if rotationStarted { viewport.rotationEnded() }
            rotationStarted = false
        default:
            break
        }
    }

    // Nur Berührungen auf den Seiten, nicht in Werkzeugleiste oder Sheets.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let scrollView, let view = touch.view else { return false }
        return view.isDescendant(of: scrollView)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// Findet die UIScrollView hinter einer SwiftUI-ScrollView (als Hintergrund des Inhalts einsetzen).
struct ScrollViewFinder: UIViewRepresentable {
    let onFind: (UIScrollView) -> Void

    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        view.isUserInteractionEnabled = false
        view.onFind = onFind
        return view
    }

    func updateUIView(_ view: FinderView, context: Context) {
        view.onFind = onFind
    }

    final class FinderView: UIView {
        var onFind: ((UIScrollView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView {
                    onFind?(scrollView)
                    return
                }
                view = current.superview
            }
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
