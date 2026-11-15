import Foundation

public struct TimestampRule: Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case pattern
        case iso8601
        case epochSeconds
        case epochMilliseconds
    }

    public var kind: Kind
    public var format: String?
    public var timeZone: String

    public static let iso8601 = TimestampRule(kind: .iso8601, format: nil, timeZone: "UTC")

    public init(kind: Kind, format: String?, timeZone: String) {
        self.kind = kind
        self.format = format
        self.timeZone = timeZone
    }

    public static func pattern(_ format: String, timeZone: String) -> TimestampRule {
        TimestampRule(kind: .pattern, format: format, timeZone: timeZone)
    }

    func validate() throws(LogProfileError) {
        guard TimeZone(identifier: timeZone) != nil else { throw .unknownTimeZone(timeZone) }
        guard kind == .pattern else { return }
        guard let format, TimestampParser.compile(format) != nil else { throw .invalidTimestampFormat(format ?? "") }
    }
}

// MARK: - Codable

extension TimestampRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case format
        case timeZone
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decodeIfPresent(String.self, forKey: .format)
        self.format = format
        self.kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? (format == nil ? .iso8601 : .pattern)
        self.timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone) ?? "UTC"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(format, forKey: .format)
        try container.encode(timeZone, forKey: .timeZone)
    }
}
