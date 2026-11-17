import Foundation

/// Schemaloser Protobuf-Leser: liefert Felder nach Nummer, ohne .proto-Definition.
struct ProtoMessage {
    enum Value {
        case varint(UInt64)
        case fixed64(UInt64)
        case fixed32(UInt32)
        case bytes(Data)
    }

    struct Field {
        let number: Int
        let value: Value
    }

    let fields: [Field]

    struct DecodeError: Error {}

    init(_ data: Data) throws {
        var reader = ByteReader(data)
        var fields: [Field] = []
        while !reader.isAtEnd {
            let key = try reader.varint()
            let number = Int(key >> 3)
            guard number > 0 else { throw DecodeError() }
            switch key & 7 {
            case 0: fields.append(Field(number: number, value: .varint(try reader.varint())))
            case 1: fields.append(Field(number: number, value: .fixed64(try reader.fixed64())))
            case 2:
                let length = Int(try reader.varint())
                fields.append(Field(number: number, value: .bytes(try reader.take(length))))
            case 5: fields.append(Field(number: number, value: .fixed32(try reader.fixed32())))
            default: throw DecodeError()
            }
        }
        self.fields = fields
    }

    /// Datei aus aneinandergereihten, längenpräfixierten Nachrichten (`<varint Länge><Nachricht>…`).
    static func delimited(_ data: Data) throws -> [Data] {
        var reader = ByteReader(data)
        var records: [Data] = []
        while !reader.isAtEnd {
            let length = Int(try reader.varint())
            records.append(try reader.take(length))
        }
        return records
    }

    func all(_ number: Int) -> [Value] { fields.filter { $0.number == number }.map(\.value) }

    func has(_ number: Int) -> Bool { fields.contains { $0.number == number } }

    func bytes(_ number: Int) -> Data? {
        for field in fields where field.number == number { if case .bytes(let d) = field.value { return d } }
        return nil
    }

    func string(_ number: Int) -> String? { bytes(number).map { String(decoding: $0, as: UTF8.self) } }

    func message(_ number: Int) -> ProtoMessage? { bytes(number).flatMap { try? ProtoMessage($0) } }

    func uint(_ number: Int) -> UInt64? {
        for field in fields where field.number == number { if case .varint(let v) = field.value { return v } }
        return nil
    }

    func float(_ number: Int) -> Float? {
        for field in fields where field.number == number {
            if case .fixed32(let v) = field.value { return Float(bitPattern: v) }
        }
        return nil
    }
}

struct ByteReader {
    struct EndOfData: Error {}

    private let data: Data
    private(set) var position: Int

    init(_ data: Data, position: Int = 0) {
        self.data = data
        self.position = position
    }

    var isAtEnd: Bool { position >= data.count }
    var remaining: Int { data.count - position }

    mutating func byte() throws -> UInt8 {
        guard position < data.count else { throw EndOfData() }
        defer { position += 1 }
        return data[data.startIndex + position]
    }

    mutating func varint() throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while shift < 70 {
            let b = try byte()
            value |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return value }
            shift += 7
        }
        throw EndOfData()
    }

    mutating func take(_ count: Int) throws -> Data {
        guard count >= 0, position + count <= data.count else { throw EndOfData() }
        defer { position += count }
        return data.subdata(in: (data.startIndex + position)..<(data.startIndex + position + count))
    }

    mutating func fixed32() throws -> UInt32 {
        var v: UInt32 = 0
        for i in 0..<4 {
            let b = try byte()
            v |= UInt32(b) << (8 * UInt32(i))
        }
        return v
    }

    mutating func fixed64() throws -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 {
            let b = try byte()
            v |= UInt64(b) << (8 * UInt64(i))
        }
        return v
    }

    mutating func u16() throws -> UInt16 {
        let low = try byte()
        let high = try byte()
        return UInt16(low) | UInt16(high) << 8
    }
}
