import Foundation
import Compression

/// Apple-LZ4-Stream (`bv41`/`bv4-` … `bv4$`), wie ihn GoodNotes für Strichdaten nutzt.
enum AppleLZ4 {
    /// Entpackt den Stream am Anfang von `data`. Liefert die Daten und die Position direkt hinter `bv4$`.
    static func decode(_ data: Data) -> (Data, Int)? {
        var reader = ByteReader(data)
        var total = 0
        while true {
            guard let magic = try? reader.take(4) else { return nil }
            if magic == Data("bv4$".utf8) { break }
            guard magic == Data("bv41".utf8) || magic == Data("bv4-".utf8),
                  let uncompressed = try? reader.fixed32(), let stored = try? reader.fixed32(),
                  (try? reader.take(Int(stored))) != nil else { return nil }
            total += Int(uncompressed)
        }
        let end = reader.position
        guard total > 0 else { return (Data(), end) }
        var output = Data(count: total)
        let written = output.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, total,
                                          src.bindMemory(to: UInt8.self).baseAddress!, end,
                                          nil, COMPRESSION_LZ4)
            }
        }
        guard written == total else { return nil }
        return (output, end)
    }
}

/// Troy-Hanson-TPL-Speicherabbild (`tpl\0…`). GoodNotes legt darin die Punkte eines Strichs ab.
struct TPLImage {
    indirect enum Value {
        case number(UInt64)
        case signed(Int64)
        case double(Double)
        case string(String)
        case blob(Data)
        case list([Value])

        /// `u`-Werte sind bei GoodNotes meist float32-Bitmuster.
        var float: CGFloat? {
            if case .number(let v) = self { return CGFloat(Float(bitPattern: UInt32(truncatingIfNeeded: v))) }
            return nil
        }

        var int: Int? {
            switch self {
            case .number(let v): Int(truncatingIfNeeded: v)
            case .signed(let v): Int(truncatingIfNeeded: v)
            default: nil
            }
        }

        var list: [Value] { if case .list(let l) = self { return l } else { return [] } }

        /// Alle Zahlen einer (verschachtelten) Liste als Floats, z. B. `A(S(uuuu))` → x1,y1,x2,y2,…
        var floats: [CGFloat] {
            switch self {
            case .list(let items): items.flatMap(\.floats)
            default: float.map { [$0] } ?? []
            }
        }
    }

    let format: String
    let values: [Value]

    private indirect enum Node {
        case scalar(Character)
        case array([Node])
        case structure([Node])
    }

    struct DecodeError: Error {}

    init(_ data: Data) throws {
        guard data.count >= 9, data.prefix(3) == Data("tpl".utf8) else { throw DecodeError() }
        guard let end = data[(data.startIndex + 8)...].firstIndex(of: 0) else { throw DecodeError() }
        format = String(decoding: data[(data.startIndex + 8)..<end], as: UTF8.self)

        var chars = Array(format)[...]
        let nodes = try Self.parse(&chars)
        var reader = ByteReader(data, position: end - data.startIndex + 1)
        values = try nodes.map { try Self.decode($0, &reader) }
    }

    private static func parse(_ chars: inout ArraySlice<Character>) throws -> [Node] {
        var nodes: [Node] = []
        while let c = chars.popFirst() {
            switch c {
            case ")": return nodes
            case "A", "S":
                guard chars.popFirst() == "(" else { throw DecodeError() }
                let children = try parse(&chars)
                nodes.append(c == "A" ? .array(children) : .structure(children))
            case "j", "v", "i", "u", "I", "U", "c", "s", "f", "B":
                nodes.append(.scalar(c))
            default:
                throw DecodeError()
            }
        }
        return nodes
    }

    private static func decode(_ node: Node, _ r: inout ByteReader) throws -> Value {
        switch node {
        case .structure(let children):
            return .list(try children.map { try decode($0, &r) })
        case .array(let children):
            let count = Int(try r.fixed32())
            guard count <= r.remaining else { throw DecodeError() }
            var items: [Value] = []
            items.reserveCapacity(count)
            for _ in 0..<count {
                if children.count == 1 {
                    items.append(try decode(children[0], &r))
                } else {
                    items.append(.list(try children.map { try decode($0, &r) }))
                }
            }
            return .list(items)
        case .scalar(let c):
            switch c {
            case "c": return .signed(Int64(Int8(bitPattern: try r.byte())))
            case "j": return .signed(Int64(Int16(bitPattern: try r.u16())))
            case "v": return .number(UInt64(try r.u16()))
            case "i": return .signed(Int64(Int32(bitPattern: try r.fixed32())))
            case "u": return .number(UInt64(try r.fixed32()))
            case "I": return .signed(Int64(bitPattern: try r.fixed64()))
            case "U": return .number(try r.fixed64())
            case "f": return .double(Double(bitPattern: try r.fixed64()))
            case "s":
                let length = Int(try r.fixed32())
                return .string(String(decoding: try r.take(max(length - 1, 0)), as: UTF8.self))
            case "B":
                return .blob(try r.take(Int(try r.fixed32())))
            default:
                throw DecodeError()
            }
        }
    }
}
