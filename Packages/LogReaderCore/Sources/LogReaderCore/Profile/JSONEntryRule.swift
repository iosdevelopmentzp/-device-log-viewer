import Foundation

public struct JSONEntryRule: Sendable, Equatable {

    public var timeKeys: [String]
    public var levelKeys: [String]
    public var messageKeys: [String]

    public static let standard = JSONEntryRule(
        timeKeys: ["timestamp", "time", "date"],
        levelKeys: ["level", "messageType", "type", "severity"],
        messageKeys: ["message", "eventMessage", "composedMessage", "msg", "text"]
    )

    public init(timeKeys: [String], levelKeys: [String], messageKeys: [String]) {
        self.timeKeys = timeKeys
        self.levelKeys = levelKeys
        self.messageKeys = messageKeys
    }
}

// MARK: - Codable

extension JSONEntryRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case time
        case level
        case message
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeKeys = try Self.keys(container, .time) ?? Self.standard.timeKeys
        self.levelKeys = try Self.keys(container, .level) ?? Self.standard.levelKeys
        self.messageKeys = try Self.keys(container, .message) ?? Self.standard.messageKeys
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeKeys, forKey: .time)
        try container.encode(levelKeys, forKey: .level)
        try container.encode(messageKeys, forKey: .message)
    }

    private static func keys(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> [String]? {
        if let single = try? container.decodeIfPresent(String.self, forKey: key) {
            return [single]
        }
        return try container.decodeIfPresent([String].self, forKey: key)
    }
}
