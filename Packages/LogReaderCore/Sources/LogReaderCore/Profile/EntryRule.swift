import Foundation

public enum EntryRule: Sendable, Equatable {
    case trailing([EntryToken])
    case leading([EntryToken])
    case regex(String)
    case json(JSONEntryRule)

    public var isJSON: Bool {
        guard case .json = self else { return false }
        return true
    }

    func validate(attributes: [AttributeRule]) throws(LogProfileError) {
        switch self {
        case .trailing(let tokens), .leading(let tokens):
            let names = Set(tokens.compactMap(\.name))
            for token in tokens {
                try token.validate(attributes: attributes)
                if let requires = token.requires, names.contains(requires) == false {
                    throw .unknownTokenReference(requires)
                }
            }
        case .regex(let pattern):
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
                guard pattern.contains("(?<message>") else { throw LogProfileError.regexWithoutMessageGroup }
                _ = regex
            } catch let error as LogProfileError {
                throw error
            } catch {
                throw .invalidRegex(error.localizedDescription)
            }
        case .json:
            break
        }
    }
}

// MARK: - Codable

extension EntryRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case tokens
        case pattern
        case time
        case level
        case message
    }

    private enum Kind: String, Codable {
        case trailing
        case leading
        case regex
        case json
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .trailing:
            self = .trailing(try container.decodeIfPresent([EntryToken].self, forKey: .tokens) ?? [])
        case .leading:
            self = .leading(try container.decodeIfPresent([EntryToken].self, forKey: .tokens) ?? [])
        case .regex:
            self = .regex(try container.decode(String.self, forKey: .pattern))
        case .json:
            self = .json(try JSONEntryRule(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .trailing(let tokens):
            try container.encode(Kind.trailing, forKey: .kind)
            try container.encode(tokens, forKey: .tokens)
        case .leading(let tokens):
            try container.encode(Kind.leading, forKey: .kind)
            try container.encode(tokens, forKey: .tokens)
        case .regex(let pattern):
            try container.encode(Kind.regex, forKey: .kind)
            try container.encode(pattern, forKey: .pattern)
        case .json(let rule):
            try container.encode(Kind.json, forKey: .kind)
            try rule.encode(to: encoder)
        }
    }
}
