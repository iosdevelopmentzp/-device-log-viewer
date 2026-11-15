import Foundation

public enum LogFileFormat: Sendable, Equatable {
    case separated(UInt8)
    case lines

    static let newline: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let maxHeaderLookup = 64 * 1024

    var terminator: UInt8 {
        switch self {
        case .separated(let separator): separator
        case .lines: Self.newline
        }
    }

    static func detect(fromFirstLine line: Data) -> LogFileFormat {
        guard let separator = separator(fromHeader: line) else { return .lines }
        return .separated(separator)
    }
}

// MARK: - Private

private extension LogFileFormat {

    struct Header: Decodable {
        let version: Int
        let separator: String

        enum CodingKeys: String, CodingKey {
            case version = "v"
            case separator = "sep"
        }
    }

    static func separator(fromHeader line: Data) -> UInt8? {
        guard line.first == UInt8(ascii: "{") else { return nil }
        guard let header = try? JSONDecoder().decode(Header.self, from: line) else { return nil }
        let bytes = Array(header.separator.utf8)
        guard bytes.count == 1 else { return nil }
        return bytes[0]
    }
}
