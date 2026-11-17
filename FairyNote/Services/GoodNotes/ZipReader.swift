import Foundation
import Compression

/// Minimaler ZIP-Leser (Central Directory, Methoden „stored“ und „deflate“). Reicht für .goodnotes-Dateien.
struct ZipReader {
    enum ZipError: LocalizedError {
        case notAZip, unsupportedMethod(Int), corrupt(String)

        var errorDescription: String? {
            switch self {
            case .notAZip: "Die Datei ist kein gültiges ZIP-Archiv."
            case .unsupportedMethod(let method): "Nicht unterstützte ZIP-Kompression (\(method))."
            case .corrupt(let name): "Beschädigter Eintrag im Archiv: \(name)"
            }
        }
    }

    private struct Entry {
        let method: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private let entries: [String: Entry]

    var names: [String] { Array(entries.keys) }

    init(data: Data) throws {
        self.data = data
        let bytes = [UInt8](data)
        // End of Central Directory: Signatur 0x06054b50, steht in den letzten 64 KB.
        guard bytes.count >= 22 else { throw ZipError.notAZip }
        var eocd = -1
        var i = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 65_535)
        while i >= lowest {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4B, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }

        let count = Int(bytes.u16(eocd + 10))
        var pos = Int(bytes.u32(eocd + 16))
        var entries: [String: Entry] = [:]
        for _ in 0..<count {
            guard pos + 46 <= bytes.count, bytes.u32(pos) == 0x0201_4B50 else { throw ZipError.notAZip }
            let method = Int(bytes.u16(pos + 10))
            let compressed = Int(bytes.u32(pos + 20))
            let uncompressed = Int(bytes.u32(pos + 24))
            let nameLength = Int(bytes.u16(pos + 28))
            let extraLength = Int(bytes.u16(pos + 30))
            let commentLength = Int(bytes.u16(pos + 32))
            let offset = Int(bytes.u32(pos + 42))
            guard pos + 46 + nameLength <= bytes.count else { throw ZipError.notAZip }
            let name = String(decoding: bytes[(pos + 46)..<(pos + 46 + nameLength)], as: UTF8.self)
            entries[name] = Entry(method: method, compressedSize: compressed,
                                  uncompressedSize: uncompressed, localHeaderOffset: offset)
            pos += 46 + nameLength + extraLength + commentLength
        }
        self.entries = entries
    }

    func contains(_ name: String) -> Bool { entries[name] != nil }

    func size(of name: String) -> Int { entries[name]?.uncompressedSize ?? 0 }

    func read(_ name: String) throws -> Data {
        guard let entry = entries[name] else { throw ZipError.corrupt(name) }
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count else { throw ZipError.corrupt(name) }
        let nameLength = Int(data.u16(header + 26))
        let extraLength = Int(data.u16(header + 28))
        let start = header + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= data.count else { throw ZipError.corrupt(name) }
        let payload = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + entry.compressedSize))

        switch entry.method {
        case 0:
            return payload
        case 8:
            if entry.uncompressedSize == 0 { return Data() }
            var output = Data(count: entry.uncompressedSize)
            let written = output.withUnsafeMutableBytes { dst in
                payload.withUnsafeBytes { src in
                    compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, entry.uncompressedSize,
                                              src.bindMemory(to: UInt8.self).baseAddress!, payload.count,
                                              nil, COMPRESSION_ZLIB) // ZLIB = rohes DEFLATE wie in ZIP
                }
            }
            guard written == entry.uncompressedSize else { throw ZipError.corrupt(name) }
            return output
        default:
            throw ZipError.unsupportedMethod(entry.method)
        }
    }
}

extension [UInt8] {
    func u16(_ i: Int) -> UInt16 { UInt16(self[i]) | UInt16(self[i + 1]) << 8 }
    func u32(_ i: Int) -> UInt32 {
        UInt32(self[i]) | UInt32(self[i + 1]) << 8 | UInt32(self[i + 2]) << 16 | UInt32(self[i + 3]) << 24
    }
}

extension Data {
    func u16(_ i: Int) -> UInt16 {
        UInt16(self[startIndex + i]) | UInt16(self[startIndex + i + 1]) << 8
    }
}
