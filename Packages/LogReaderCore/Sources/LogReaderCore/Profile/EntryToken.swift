import Foundation

public struct EntryToken: Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case time
        case level
        case delimited
        case word
        case list
        case literal
    }

    public enum Pattern: String, Codable, Sendable {
        case fileLine = "file:line"
    }

    public var kind: Kind
    public var attribute: String?
    public var open: String?
    public var close: String?
    public var prefix: String?
    public var text: String?
    public var pattern: Pattern?
    public var required: Bool
    public var requires: String?

    public var name: String? {
        switch kind {
        case .time, .level: kind.rawValue
        case .delimited, .word, .list: attribute
        case .literal: nil
        }
    }

    public init(
        kind: Kind,
        attribute: String?,
        open: String?,
        close: String?,
        prefix: String?,
        text: String?,
        pattern: Pattern?,
        required: Bool,
        requires: String?
    ) {
        self.kind = kind
        self.attribute = attribute
        self.open = open
        self.close = close
        self.prefix = prefix
        self.text = text
        self.pattern = pattern
        self.required = required
        self.requires = requires
    }

    public static func time(required: Bool) -> EntryToken {
        EntryToken(kind: .time, attribute: nil, open: nil, close: nil, prefix: nil, text: nil, pattern: nil, required: required, requires: nil)
    }

    public static func level(required: Bool) -> EntryToken {
        EntryToken(kind: .level, attribute: nil, open: nil, close: nil, prefix: nil, text: nil, pattern: nil, required: required, requires: nil)
    }

    public static func delimited(_ attribute: String, open: String, close: String, pattern: Pattern?, requires: String?) -> EntryToken {
        EntryToken(kind: .delimited, attribute: attribute, open: open, close: close, prefix: nil, text: nil, pattern: pattern, required: false, requires: requires)
    }

    public static func word(_ attribute: String, required: Bool) -> EntryToken {
        EntryToken(kind: .word, attribute: attribute, open: nil, close: nil, prefix: nil, text: nil, pattern: nil, required: required, requires: nil)
    }

    public static func list(_ attribute: String, prefix: String, requires: String?) -> EntryToken {
        EntryToken(kind: .list, attribute: attribute, open: nil, close: nil, prefix: prefix, text: nil, pattern: nil, required: false, requires: requires)
    }

    public static func literal(_ text: String) -> EntryToken {
        EntryToken(kind: .literal, attribute: nil, open: nil, close: nil, prefix: nil, text: text, pattern: nil, required: true, requires: nil)
    }

    func validate(attributes: [AttributeRule]) throws(LogProfileError) {
        switch kind {
        case .time, .level:
            guard (open ?? "").isEmpty == (close ?? "").isEmpty else { throw .tokenWithoutDelimiters }
        case .delimited:
            guard let open, let close, open.isEmpty == false, close.isEmpty == false else { throw .tokenWithoutDelimiters }
            try validateAttribute(attributes)
        case .word:
            try validateAttribute(attributes)
        case .list:
            guard let prefix, prefix.isEmpty == false else { throw .tokenWithoutPrefix }
            try validateAttribute(attributes)
        case .literal:
            guard let text, text.isEmpty == false else { throw .tokenWithoutText }
        }
    }
}

// MARK: - Codable

extension EntryToken: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case attribute
        case open
        case close
        case prefix
        case text
        case pattern
        case required
        case requires
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(Kind.self, forKey: .kind)
        self.attribute = try container.decodeIfPresent(String.self, forKey: .attribute)
        self.open = try container.decodeIfPresent(String.self, forKey: .open)
        self.close = try container.decodeIfPresent(String.self, forKey: .close)
        self.prefix = try container.decodeIfPresent(String.self, forKey: .prefix)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.pattern = try container.decodeIfPresent(Pattern.self, forKey: .pattern)
        self.required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? (kind == .literal)
        self.requires = try container.decodeIfPresent(String.self, forKey: .requires)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(attribute, forKey: .attribute)
        try container.encodeIfPresent(open, forKey: .open)
        try container.encodeIfPresent(close, forKey: .close)
        try container.encodeIfPresent(prefix, forKey: .prefix)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(pattern, forKey: .pattern)
        if required != (kind == .literal) {
            try container.encode(required, forKey: .required)
        }
        try container.encodeIfPresent(requires, forKey: .requires)
    }
}

// MARK: - Private

private extension EntryToken {

    func validateAttribute(_ attributes: [AttributeRule]) throws(LogProfileError) {
        guard let attribute, attribute.isEmpty == false else { throw .tokenWithoutAttribute(kind.rawValue) }
        guard attributes.contains(where: { $0.id == attribute }) else { throw .unknownAttribute(attribute) }
    }
}
