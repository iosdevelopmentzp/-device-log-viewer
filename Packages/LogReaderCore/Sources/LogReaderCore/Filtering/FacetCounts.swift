import Foundation

public struct FacetCounts: Sendable, Equatable {

    public struct Entry: Sendable, Hashable, Identifiable {
        public let value: String
        public let count: Int

        public var id: String { value }

        public init(value: String, count: Int) {
            self.value = value
            self.count = count
        }
    }

    private struct AttributeFacet: Sendable, Equatable {
        let column: FacetColumn
        let index: Int
        let rule: AttributeRule
    }

    private let levelIDs: [String]
    private let attributeFacets: [AttributeFacet]
    private var counts: [FacetColumn: [String: Int]]

    public init(profile: LogProfile) {
        self.levelIDs = profile.levels.map(\.id)
        self.attributeFacets = profile.attributes.enumerated()
            .filter { $0.element.facet }
            .map { AttributeFacet(column: .attribute($0.element.id), index: $0.offset, rule: $0.element) }
        self.counts = [:]
    }

    public mutating func add(_ records: ArraySlice<LogRecord>) {
        for record in records {
            if let level = record.level, levelIDs.indices.contains(level.index) {
                counts[.level, default: [:]][levelIDs[level.index], default: 0] += 1
            }
            for facet in attributeFacets where record.attributes.indices.contains(facet.index) {
                for value in facet.rule.facetValues(of: record.attributes[facet.index]) {
                    counts[facet.column, default: [:]][value, default: 0] += 1
                }
            }
        }
    }

    public mutating func removeAll() {
        counts = [:]
    }

    public func count(of value: String, in column: FacetColumn) -> Int {
        counts[column]?[value] ?? 0
    }

    public func entries(in column: FacetColumn) -> [Entry] {
        guard column != .level else {
            return levelIDs.map { Entry(value: $0, count: count(of: $0, in: .level)) }
        }
        return (counts[column] ?? [:])
            .map { Entry(value: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                guard lhs.count == rhs.count else { return lhs.count > rhs.count }
                return lhs.value.localizedStandardCompare(rhs.value) == .orderedAscending
            }
    }
}
