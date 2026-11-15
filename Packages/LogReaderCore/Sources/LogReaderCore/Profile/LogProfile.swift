import Foundation

public struct LogProfile: Sendable, Equatable {

    public var name: String
    public var discovery: DiscoveryRule?
    public var framing: FramingRule
    public var entry: EntryRule
    public var timestamp: TimestampRule
    public var levels: [LevelRule]
    public var attributes: [AttributeRule]
    public var fields: FieldsRule
    public var source: SourceRule

    public var facetAttributes: [AttributeRule] { attributes.filter(\.facet) }

    public var sourceAttributeIndex: Int? {
        attributes.firstIndex { $0.role == .source }
    }

    public var alertLevels: [LogLevel] {
        levels.indices.filter { levels[$0].alerts }.map(LogLevel.init(index:))
    }

    public init(
        name: String,
        discovery: DiscoveryRule?,
        framing: FramingRule,
        entry: EntryRule,
        timestamp: TimestampRule,
        levels: [LevelRule],
        attributes: [AttributeRule],
        fields: FieldsRule,
        source: SourceRule
    ) {
        self.name = name
        self.discovery = discovery
        self.framing = framing
        self.entry = entry
        self.timestamp = timestamp
        self.levels = levels
        self.attributes = attributes
        self.fields = fields
        self.source = source
    }

    public func level(id: String) -> LogLevel? {
        levels.firstIndex { $0.id == id }.map(LogLevel.init(index:))
    }

    public func rule(of level: LogLevel) -> LevelRule? {
        levels.indices.contains(level.index) ? levels[level.index] : nil
    }

    public func attributeIndex(id: String) -> Int? {
        attributes.firstIndex { $0.id == id }
    }

    public func attribute(id: String) -> AttributeRule? {
        attributeIndex(id: id).map { attributes[$0] }
    }

    public func value(of record: LogRecord, attribute index: Int) -> AttributeValue {
        record.attributes.indices.contains(index) ? record.attributes[index] : .none
    }

    public func value(of record: LogRecord, attributeID: String) -> AttributeValue {
        attributeIndex(id: attributeID).map { value(of: record, attribute: $0) } ?? .none
    }

    public func source(of record: LogRecord) -> String? {
        sourceAttributeIndex.flatMap { value(of: record, attribute: $0).text }
    }

    public func sourceReference(of record: LogRecord) -> SourceReference? {
        source(of: record).flatMap(SourceReference.parse)
    }

    public func validate() throws(LogProfileError) {
        guard name.isEmpty == false else { throw .emptyName }
        guard levels.isEmpty == false else { throw .noLevels }
        var seen = Set<String>()
        for level in levels {
            guard level.id.isEmpty == false, seen.insert(level.id).inserted else { throw .duplicateLevel(level.id) }
            guard level.codes.isEmpty == false else { throw .levelWithoutCodes(level.id) }
        }
        seen.removeAll()
        for attribute in attributes {
            guard attribute.id.isEmpty == false, seen.insert(attribute.id).inserted else {
                throw .duplicateAttribute(attribute.id)
            }
            guard Self.reservedIDs.contains(attribute.id) == false else { throw .reservedAttribute(attribute.id) }
        }
        guard attributes.filter({ $0.role == .source }).count <= 1 else { throw .severalSourceAttributes }
        try framing.validate()
        try entry.validate(attributes: attributes)
        try timestamp.validate()
        guard fields.indent >= 1 else { throw .invalidFieldIndent }
    }

    static let reservedIDs: Set<String> = ["level", "message", "time", "number", "delta"]
}

// MARK: - Codable

extension LogProfile: Codable {

    private enum CodingKeys: String, CodingKey {
        case name
        case discovery
        case framing
        case entry
        case timestamp
        case levels
        case attributes
        case fields
        case source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.discovery = try container.decodeIfPresent(DiscoveryRule.self, forKey: .discovery)
        self.framing = try container.decodeIfPresent(FramingRule.self, forKey: .framing) ?? .lines(joinsUnrecognizedLines: false)
        self.entry = try container.decode(EntryRule.self, forKey: .entry)
        self.timestamp = try container.decodeIfPresent(TimestampRule.self, forKey: .timestamp) ?? .iso8601
        self.levels = try container.decodeIfPresent([LevelRule].self, forKey: .levels) ?? LevelRule.standard
        self.attributes = try container.decodeIfPresent([AttributeRule].self, forKey: .attributes) ?? []
        self.fields = try container.decodeIfPresent(FieldsRule.self, forKey: .fields) ?? .standard
        self.source = try container.decodeIfPresent(SourceRule.self, forKey: .source) ?? .standard
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(discovery, forKey: .discovery)
        try container.encode(framing, forKey: .framing)
        try container.encode(entry, forKey: .entry)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(levels, forKey: .levels)
        try container.encode(attributes, forKey: .attributes)
        try container.encode(fields, forKey: .fields)
        try container.encode(source, forKey: .source)
    }
}
