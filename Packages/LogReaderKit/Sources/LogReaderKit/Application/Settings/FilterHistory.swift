import Foundation

public struct FilterHistory: Codable, Equatable, Sendable {

    public private(set) var entries: [RecentFilterSet]

    public static let empty = FilterHistory(entries: [])
    public static let limit = 10

    public init(entries: [RecentFilterSet]) {
        self.entries = entries
    }

    public func entry(id: UUID) -> RecentFilterSet? {
        entries.first { $0.id == id }
    }

    public func adding(_ entry: RecentFilterSet) -> FilterHistory {
        var added = entry
        if let existing = entries.first(where: { $0.isSameFilter(as: entry) }) {
            added = RecentFilterSet(
                id: existing.id,
                facets: entry.facets,
                bookmarksOnly: entry.bookmarksOnly,
                date: entry.date
            )
        }
        let others = entries.filter { $0.isSameFilter(as: entry) == false }
        return FilterHistory(entries: Array(([added] + others).prefix(Self.limit)))
    }

    public func removing(id: UUID) -> FilterHistory {
        FilterHistory(entries: entries.filter { $0.id != id })
    }
}
