import Foundation

public struct FacetSelection: Sendable, Equatable {

    public private(set) var filters: [FacetColumn: FacetFilter<String>]

    public var isAll: Bool { filters.isEmpty }

    public var levels: FacetFilter<String> { self[.level] }

    public var activeColumns: [FacetColumn] {
        filters.keys.sorted { $0.rawValue < $1.rawValue }
    }

    public static let all = FacetSelection(filters: [:])

    public init(filters: [FacetColumn: FacetFilter<String>]) {
        self.filters = filters.filter { $0.value.isAll == false }
    }

    public subscript(column: FacetColumn) -> FacetFilter<String> {
        get { filters[column] ?? .all }
        set { filters[column] = newValue.isAll ? nil : newValue }
    }

    public func isActive(_ column: FacetColumn) -> Bool {
        self[column].isAll == false
    }

    public func isSelected(_ value: String, in column: FacetColumn) -> Bool {
        self[column].isSelected(value)
    }

    public func isExcluding(_ column: FacetColumn) -> Bool {
        self[column].isExcluding
    }

    public func mode(of column: FacetColumn) -> FacetMode {
        isExcluding(column) ? .exclude : .include
    }

    public func values(in column: FacetColumn) -> Set<String> {
        self[column].values
    }

    public mutating func toggle(_ value: String, in column: FacetColumn) {
        self[column] = self[column].togglingSelection(value)
    }

    public mutating func showOnly(_ values: Set<String>, in column: FacetColumn) {
        guard values.isEmpty == false else {
            showAll(in: column)
            return
        }
        self[column] = .only(values)
    }

    public mutating func exclude(_ values: Set<String>, in column: FacetColumn) {
        guard values.isEmpty == false else {
            showAll(in: column)
            return
        }
        self[column] = .except(values)
    }

    public mutating func addExcluded(_ values: Set<String>, in column: FacetColumn) {
        for value in values {
            self[column] = self[column].excluding(value)
        }
    }

    public mutating func setMode(_ mode: FacetMode, in column: FacetColumn) {
        let values = self[column].values
        guard values.isEmpty == false else { return }
        switch mode {
        case .include: self[column] = .only(values)
        case .exclude: self[column] = .except(values)
        }
    }

    public mutating func showAll(in column: FacetColumn) {
        self[column] = .all
    }
}

// MARK: - Codable

extension FacetSelection: Codable {

    private enum CodingKeys: String, CodingKey {
        case facets
        case levels
        case columns
    }

    private static let legacyLevelIDs = ["debug", "info", "notice", "warning", "error", "fault"]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let facets = try container.decodeIfPresent([String: FacetFilter<String>].self, forKey: .facets) {
            self.init(filters: Dictionary(uniqueKeysWithValues: facets.map { (FacetColumn(rawValue: $0.key), $0.value) }))
            return
        }
        var filters: [FacetColumn: FacetFilter<String>] = [:]
        let columns = try container.decodeIfPresent([String: FacetFilter<String>].self, forKey: .columns) ?? [:]
        for (key, filter) in columns {
            filters[FacetColumn(rawValue: key)] = filter
        }
        if let levels = try container.decodeIfPresent(FacetFilter<Int>.self, forKey: .levels) {
            filters[.level] = Self.levelIDs(of: levels)
        }
        self.init(filters: filters)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let facets = Dictionary(uniqueKeysWithValues: filters.map { ($0.key.rawValue, $0.value) })
        try container.encode(facets, forKey: .facets)
    }

    private static func levelIDs(of filter: FacetFilter<Int>) -> FacetFilter<String> {
        let ids = Set(filter.values.compactMap { legacyLevelIDs.indices.contains($0) ? legacyLevelIDs[$0] : nil })
        guard ids.isEmpty == false else { return .all }
        return filter.isExcluding ? .except(ids) : .only(ids)
    }
}
