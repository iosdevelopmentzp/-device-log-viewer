import Foundation

public enum FramingRule: Sendable, Equatable {
    case header
    case separator(String)
    case lines(joinsUnrecognizedLines: Bool)

    var separatorByte: UInt8? {
        guard case .separator(let text) = self, let byte = text.utf8.first, text.utf8.count == 1 else { return nil }
        return byte
    }

    var joinsUnrecognizedLines: Bool {
        guard case .lines(let joins) = self else { return false }
        return joins
    }

    func validate() throws(LogProfileError) {
        guard case .separator = self else { return }
        guard separatorByte != nil else { throw .invalidSeparator }
    }
}

// MARK: - Codable

extension FramingRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case separator
        case joinsUnrecognizedLines
    }

    private enum Kind: String, Codable {
        case header
        case separator
        case lines
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .header:
            self = .header
        case .separator:
            self = .separator(try container.decodeIfPresent(String.self, forKey: .separator) ?? "")
        case .lines:
            self = .lines(joinsUnrecognizedLines: try container.decodeIfPresent(Bool.self, forKey: .joinsUnrecognizedLines) ?? false)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .header:
            try container.encode(Kind.header, forKey: .kind)
        case .separator(let separator):
            try container.encode(Kind.separator, forKey: .kind)
            try container.encode(separator, forKey: .separator)
        case .lines(let joins):
            try container.encode(Kind.lines, forKey: .kind)
            try container.encode(joins, forKey: .joinsUnrecognizedLines)
        }
    }
}
