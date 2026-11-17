import Foundation
import CoreGraphics

/// Liest eine .goodnotes-Datei (ZIP mit Protobuf-Datensätzen und LZ4/TPL-Strichdaten).
///
/// Aufbau (ermittelt an Beispieldateien, siehe auch das MIT-lizenzierte Projekt „parser-for-goodnotes“):
/// - `index.notes.pb`: Seiten (UUID → `notes/<UUID>`), `index.attachments.pb`: Anhänge (ID → Pfad)
/// - `index.events.pb`: Ereignisprotokoll. Feld 2 = Vorlage (Anhang, PDF-Seite, Größe), Feld 54 = Seite angelegt
///   (Vorlage + Sortierschlüssel), Feld 55 = Seite verschoben, Feld 56 = Seite gelöscht.
/// - `notes/<UUID>`: Kopf-Datensatz (Feld 3 = gelöscht, Feld 16 = Typ) gefolgt von Inhalt (Feld 7).
///   Inhalt: Feld 2 = LZ4/TPL-Geometrie, 3 = Werkzeug, 4 = Farbe RGBA, 6 = Verschiebung (Lasso).
/// Koordinaten sind in 132 dpi, PDF-Punkte in 72 dpi.
struct GoodNotesDocument {
    static let pointsPerUnit: CGFloat = 72 / 132

    struct Color { var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1 }

    struct StrokePoint { var x: CGFloat, y: CGFloat, force: CGFloat = 1 }

    enum Tool { case pen, highlighter, pencil }

    /// Strich mit Mittellinie, wird zu einem bearbeitbaren PencilKit-Strich.
    struct Stroke {
        var tool: Tool
        var color: Color
        var width: CGFloat
        var points: [StrokePoint]
    }

    /// Fertige Umrissfläche (z. B. Füller-Striche), wird als Vektor in den Hintergrund gezeichnet.
    struct Fill {
        var color: Color
        var path: CGPath
    }

    struct Background {
        var attachmentPath: String
        var pdfPageIndex: Int   // 0-basiert
    }

    struct Page {
        var size: CGSize        // GoodNotes-Einheiten
        var background: Background?
        var strokes: [Stroke] = []
        var fills: [Fill] = []
        var skippedElements = 0
    }

    let pages: [Page]
    private let zip: ZipReader

    func attachment(_ path: String) -> Data? { try? zip.read(path) }

    init(data: Data) throws {
        let zip = try ZipReader(data: data)
        self.zip = zip
        guard zip.contains("index.notes.pb") else { throw ImportFailure.notGoodNotes }

        // Seiten und Anhänge
        var pageEntries: [(uuid: String, path: String)] = []
        for record in try ProtoMessage.delimited(zip.read("index.notes.pb")) {
            if let m = try? ProtoMessage(record), let uuid = m.string(1), let path = m.string(2) {
                pageEntries.append((uuid, path))
            }
        }
        var attachments: [String: String] = [:]
        if zip.contains("index.attachments.pb") {
            for record in try ProtoMessage.delimited(zip.read("index.attachments.pb")) {
                if let m = try? ProtoMessage(record), let id = m.string(1), let path = m.string(2) { attachments[id] = path }
            }
        }

        // Ereignisse: Vorlagen, Seitenreihenfolge, gelöschte Seiten
        struct Template { var attachment: String?; var pdfPage: Int; var size: CGSize? }
        var templates: [String: Template] = [:]
        var pageTemplate: [String: String] = [:]
        var orderKey: [String: String] = [:]
        var deleted: Set<String> = []
        // Die UUIDs in Ereignissen weichen teils im letzten Zeichen ab, darum nur die ersten 35 vergleichen.
        let key: (String) -> String = { String($0.uppercased().prefix(35)) }

        if zip.contains("index.events.pb") {
            for record in try ProtoMessage.delimited(zip.read("index.events.pb")) {
                guard let event = try? ProtoMessage(record) else { continue }
                if let t = event.message(2), let id = t.string(2) {
                    var size: CGSize?
                    if let s = t.message(8), let w = s.float(1), let h = s.float(2), w > 0, h > 0 {
                        size = CGSize(width: CGFloat(w), height: CGFloat(h))
                    }
                    templates[id] = Template(attachment: t.string(4), pdfPage: Int(t.uint(5) ?? 1), size: size)
                }
                if let p = event.message(54), let page = p.string(2) {
                    if let t = p.message(3)?.string(1) { pageTemplate[key(page)] = t }
                    if let o = p.message(4)?.string(1) { orderKey[key(page)] = o }
                }
                if let p = event.message(55), let page = p.string(2), let o = p.message(3)?.string(1) {
                    orderKey[key(page)] = o
                }
                if let p = event.message(56), let page = p.string(2) {
                    deleted.insert(key(page))
                }
            }
        }

        let ordered = pageEntries.enumerated()
            .filter { !deleted.contains(key($0.element.uuid)) && zip.contains($0.element.path) }
            .sorted { a, b in
                let ka = orderKey[key(a.element.uuid)], kb = orderKey[key(b.element.uuid)]
                switch (ka, kb) {
                case let (x?, y?) where x != y:
                    // Byteweise vergleichen wie GoodNotes (ASCII-Sortierschlüssel).
                    return Array(x.utf8).lexicographicallyPrecedes(Array(y.utf8))
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)

        let defaultSize = CGSize(width: 595.28 / Self.pointsPerUnit, height: 841.89 / Self.pointsPerUnit)
        pages = ordered.map { entry in
            let template = pageTemplate[key(entry.uuid)].flatMap { templates[$0] }
            var page = Page(size: template?.size ?? defaultSize)
            if let att = template?.attachment, let path = attachments[att] ?? (zip.contains("attachments/\(att)") ? "attachments/\(att)" : nil) {
                page.background = Background(attachmentPath: path, pdfPageIndex: max((template?.pdfPage ?? 1) - 1, 0))
            }
            if zip.size(of: entry.path) > 0, let data = try? zip.read(entry.path) {
                Self.parseElements(data, into: &page)
            }
            return page
        }
    }

    enum ImportFailure: LocalizedError {
        case notGoodNotes

        var errorDescription: String? { "Die Datei ist keine gültige GoodNotes-Datei." }
    }

    // MARK: - Elemente einer Seite

    private static func parseElements(_ data: Data, into page: inout Page) {
        guard let records = try? ProtoMessage.delimited(data) else { return }
        var header: ProtoMessage?
        for record in records {
            guard let m = try? ProtoMessage(record) else { continue }
            guard let body = m.message(7) else {
                // Kopf-Datensatz eines Strichs, oder ein anderes Element (Form, Text, Bild).
                if m.has(1) { header = m } else { page.skippedElements += 1 }
                continue
            }
            defer { header = nil }
            if header?.uint(3) == 1 { continue }   // gelöscht / radiert

            guard let geometry = body.bytes(2), geometry.starts(with: Data("bv4".utf8)),
                  let decoded = AppleLZ4.decode(geometry),
                  let image = try? TPLImage(decoded.0) else {
                page.skippedElements += 1
                continue
            }

            var color = Color()
            if let c = body.message(4) {
                color = Color(r: CGFloat(c.float(1) ?? 0), g: CGFloat(c.float(2) ?? 0),
                              b: CGFloat(c.float(3) ?? 0), a: CGFloat(c.float(4) ?? 1))
            }
            var offset = CGPoint.zero
            if let o = body.message(6) {
                offset = CGPoint(x: CGFloat(o.float(1) ?? 0), y: CGFloat(o.float(2) ?? 0))
            }

            let fmt = image.format
            if fmt.hasPrefix("vuA(v)A(S(uu))A(S(uuuu))") {
                page.strokes += penStrokes(image, color: color, offset: offset)
            } else if fmt.contains("A(S(uuuuuuuuuuu))") {
                if let s = pencilStroke(image, color: color, offset: offset) { page.strokes.append(s) }
            } else if fmt.contains("A(v)A(u)A(u)A(v)A(v)") {
                if let path = outlinePath(image, offset: offset) { page.fills.append(Fill(color: color, path: path)) }
            } else {
                page.skippedElements += 1
            }
        }
    }

    private static func valid(_ v: CGFloat) -> Bool { v.isFinite && abs(v) < 100_000 }

    /// Kugelschreiber/Textmarker: Startpunkt + quadratische Segmente (Kontrollpunkt, Endpunkt).
    /// Flag 0 vor einem Segment heißt „Stift abgesetzt“, dann beginnt ein neuer Strich.
    private static func penStrokes(_ image: TPLImage, color: Color, offset: CGPoint) -> [Stroke] {
        let v = image.values
        guard v.count > 4, let width = v[1].float, valid(width) else { return [] }
        let flags = v[2].list.compactMap(\.int)
        let tool: Tool = color.a < 0.95 ? .highlighter : .pen

        var strokes: [Stroke] = []
        var current: [StrokePoint] = []
        let start = v[3].floats
        if start.count >= 2, valid(start[0]), valid(start[1]) {
            current.append(StrokePoint(x: start[0] + offset.x, y: start[1] + offset.y))
        }
        func flush() {
            if !current.isEmpty { strokes.append(Stroke(tool: tool, color: color, width: width, points: current)) }
            current = []
        }
        for (i, segment) in v[4].list.enumerated() {
            let q = segment.floats
            guard q.count >= 4, q.allSatisfy(valid) else { continue }
            let control = CGPoint(x: q[0] + offset.x, y: q[1] + offset.y)
            let end = CGPoint(x: q[2] + offset.x, y: q[3] + offset.y)
            if i + 1 < flags.count, flags[i + 1] == 0 {
                flush()
                current = [StrokePoint(x: end.x, y: end.y)]
                continue
            }
            guard let last = current.last else { current = [StrokePoint(x: end.x, y: end.y)]; continue }
            // Quadratische Kurve abtasten, damit PencilKit die Rundung nachbildet.
            let p0 = CGPoint(x: last.x, y: last.y)
            for step in 1...4 {
                let t = CGFloat(step) / 4, u = 1 - t
                current.append(StrokePoint(x: u * u * p0.x + 2 * u * t * control.x + t * t * end.x,
                                           y: u * u * p0.y + 2 * u * t * control.y + t * t * end.y))
            }
        }
        flush()
        return strokes
    }

    /// Bleistift: Startpunkt (x, y, Azimut, Höhe, Druck) und Segmente (Seed, 2 × (x, y, Azimut, Höhe, Druck)).
    private static func pencilStroke(_ image: TPLImage, color: Color, offset: CGPoint) -> Stroke? {
        let v = image.values
        guard v.count > 4, let width = v[1].float, valid(width) else { return nil }
        var points: [StrokePoint] = []
        func add(_ f: ArraySlice<CGFloat>) {
            let a = Array(f)
            guard a.count >= 5, valid(a[0]), valid(a[1]) else { return }
            let force = (0.01...5).contains(a[4]) ? a[4] : 0.5
            points.append(StrokePoint(x: a[0] + offset.x, y: a[1] + offset.y, force: force))
        }
        for start in v[3].list { add(start.floats[...]) }
        for segment in v[4].list {
            let f = segment.floats
            guard f.count >= 11 else { continue }
            add(f[1..<6])
            add(f[6..<11])
        }
        guard !points.isEmpty else { return nil }
        return Stroke(tool: .pencil, color: color, width: width, points: points)
    }

    /// Umrisse als CGPath-Befehle (Füller, radierte Striche): Anzahl je Teilfläche, Befehlscodes,
    /// Startpunkte, kubische Kurven, Kreis- und Ellipsenbögen.
    private static func outlinePath(_ image: TPLImage, offset: CGPoint) -> CGPath? {
        let v = image.values
        let shift = image.format.hasPrefix("vu") ? 1 : 0
        guard v.count > 9 + shift else { return nil }
        let counts = v[4 + shift].list.compactMap(\.int)
        let commands = v[5 + shift].list.compactMap(\.int)
        let starts = v[6 + shift].floats
        let cubics = v[8 + shift].floats
        let arcs = v[9 + shift].floats
        let (move, cubic, arc, ellipse) = shift == 1 ? (2, 4, 5, 8) : (0, 2, 3, 6)

        let path = CGMutablePath()
        var ci = 0, si = 0, bi = 0, ai = 0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x + offset.x, y: y + offset.y) }
        for count in counts {
            var started = false
            for command in commands[min(ci, commands.count)..<min(ci + count, commands.count)] {
                switch command {
                case move where si + 1 < starts.count:
                    path.move(to: pt(starts[si], starts[si + 1])); si += 2; started = true
                case cubic where bi + 5 < cubics.count:
                    let c1 = pt(cubics[bi], cubics[bi + 1]), c2 = pt(cubics[bi + 2], cubics[bi + 3])
                    let end = pt(cubics[bi + 4], cubics[bi + 5])
                    bi += 6
                    if !started { path.move(to: end); started = true } else { path.addCurve(to: end, control1: c1, control2: c2) }
                case arc where ai + 4 < arcs.count:
                    let c = pt(arcs[ai], arcs[ai + 1]), r = arcs[ai + 2], a0 = arcs[ai + 3], a1 = arcs[ai + 4]
                    ai += 5
                    sampleArc(path, &started, { a in CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)) }, from: a0, to: a1)
                case ellipse where ai + 6 < arcs.count:
                    let c = pt(arcs[ai], arcs[ai + 1]), rx = arcs[ai + 2], ry = arcs[ai + 3]
                    let a0 = arcs[ai + 4], a1 = arcs[ai + 5], rot = arcs[ai + 6]
                    ai += 7
                    sampleArc(path, &started, { a in
                        CGPoint(x: c.x + rx * cos(a) * cos(rot) - ry * sin(a) * sin(rot),
                                y: c.y + rx * cos(a) * sin(rot) + ry * sin(a) * cos(rot))
                    }, from: a0, to: a1)
                default:
                    break
                }
            }
            ci += count
            if started { path.closeSubpath() }
        }
        return path.isEmpty ? nil : path
    }

    /// Bogen als kurze Linienstücke (Richtung ergibt sich aus Start- und Endwinkel).
    private static func sampleArc(_ path: CGMutablePath, _ started: inout Bool,
                                  _ point: (CGFloat) -> CGPoint, from a0: CGFloat, to a1: CGFloat) {
        guard a0.isFinite, a1.isFinite else { return }
        for i in 0...8 {
            let p = point(a0 + (a1 - a0) * CGFloat(i) / 8)
            if !started { path.move(to: p); started = true } else { path.addLine(to: p) }
        }
    }
}
