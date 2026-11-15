import Foundation

public struct FacetColumn: Hashable, Sendable, Codable, RawRepresentable {

    public let rawValue: String

    public static let level = FacetColumn(rawValue: "level")

    public var isLevel: Bool { self == .level }

    public var attributeID: String? { isLevel ? nil : rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func attribute(_ id: String) -> FacetColumn {
        FacetColumn(rawValue: id)
    }

    public static func all(in profile: LogProfile) -> [FacetColumn] {
        [.level] + profile.facetAttributes.map { .attribute($0.id) }
    }

    public func values(of record: LogRecord, profile: LogProfile) -> [String] {
        guard isLevel == false else {
            return record.level.flatMap(profile.rule(of:)).map { [$0.id] } ?? []
        }
        guard let index = profile.attributeIndex(id: rawValue) else { return [] }
        return profile.attributes[index].facetValues(of: profile.value(of: record, attribute: index))
    }
}
