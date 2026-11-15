import Foundation

public struct AttributeRule: Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case text
        case list
    }

    public enum Role: String, Codable, Sendable {
        case source
    }

    public var id: String
    public var title: String
    public var kind: Kind
    public var prefix: String
    public var facet: Bool
    public var searchable: Bool
    public var role: Role?
    public var key: String
    public var lineKey: String?
    public var columnWidth: Int
    public var hidden: Bool

    public static let standardColumnWidth = 110

    public init(
        id: String,
        title: String,
        kind: Kind,
        prefix: String,
        facet: Bool,
        searchable: Bool,
        role: Role?,
        key: String,
        lineKey: String?,
        columnWidth: Int,
        hidden: Bool
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.prefix = prefix
        self.facet = facet
        self.searchable = searchable
        self.role = role
        self.key = key
        self.lineKey = lineKey
        self.columnWidth = columnWidth
        self.hidden = hidden
    }

    public static func text(_ id: String, title: String, columnWidth: Int) -> AttributeRule {
        AttributeRule(id: id, title: title, kind: .text, prefix: "", facet: true, searchable: true, role: nil, key: id, lineKey: nil, columnWidth: columnWidth, hidden: false)
    }

    public static func list(_ id: String, title: String, prefix: String, columnWidth: Int) -> AttributeRule {
        AttributeRule(id: id, title: title, kind: .list, prefix: prefix, facet: true, searchable: true, role: nil, key: id, lineKey: nil, columnWidth: columnWidth, hidden: false)
    }

    public static func source(_ id: String, title: String, key: String, lineKey: String?, columnWidth: Int) -> AttributeRule {
        AttributeRule(id: id, title: title, kind: .text, prefix: "", facet: true, searchable: true, role: .source, key: key, lineKey: lineKey, columnWidth: columnWidth, hidden: false)
    }

    public func facetValues(of value: AttributeValue) -> [String] {
        guard role == .source else { return value.values }
        return value.values.map { SourceReference.parse($0)?.fileName ?? $0 }
    }
}

// MARK: - Codable

extension AttributeRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case kind
        case prefix
        case facet
        case searchable
        case role
        case key
        case lineKey
        case columnWidth
        case hidden
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? id.capitalized
        self.kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .text
        self.prefix = try container.decodeIfPresent(String.self, forKey: .prefix) ?? ""
        self.facet = try container.decodeIfPresent(Bool.self, forKey: .facet) ?? true
        self.searchable = try container.decodeIfPresent(Bool.self, forKey: .searchable) ?? true
        self.role = try container.decodeIfPresent(Role.self, forKey: .role)
        self.key = try container.decodeIfPresent(String.self, forKey: .key) ?? id
        self.lineKey = try container.decodeIfPresent(String.self, forKey: .lineKey)
        self.columnWidth = try container.decodeIfPresent(Int.self, forKey: .columnWidth) ?? Self.standardColumnWidth
        self.hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(prefix, forKey: .prefix)
        try container.encode(facet, forKey: .facet)
        try container.encode(searchable, forKey: .searchable)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(key, forKey: .key)
        try container.encodeIfPresent(lineKey, forKey: .lineKey)
        try container.encode(columnWidth, forKey: .columnWidth)
        try container.encode(hidden, forKey: .hidden)
    }
}
