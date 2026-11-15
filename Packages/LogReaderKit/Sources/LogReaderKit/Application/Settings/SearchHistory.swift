import Foundation

public struct SearchHistory: Codable, Equatable, Sendable {

    public private(set) var entries: [RecentSearch]

    public static let empty = SearchHistory(entries: [])
    public static let unpinnedLimit = 30

    public init(entries: [RecentSearch]) {
        self.entries = entries
    }

    public func entry(id: UUID) -> RecentSearch? {
        entries.first { $0.id == id }
    }

    public func adding(_ entry: RecentSearch) -> SearchHistory {
        var added = entry
        if let existing = entries.first(where: { $0.isSameSearch(as: entry) }) {
            added = RecentSearch(
                id: existing.id,
                text: entry.text,
                mode: entry.mode,
                scope: entry.scope,
                isRegex: entry.isRegex,
                date: entry.date,
                isPinned: existing.isPinned
            )
        }
        let others = entries.filter { $0.isSameSearch(as: entry) == false }
        return SearchHistory(entries: Self.ordered([added] + others))
    }

    public func removing(id: UUID) -> SearchHistory {
        SearchHistory(entries: entries.filter { $0.id != id })
    }

    public func togglingPin(id: UUID) -> SearchHistory {
        let toggled = entries.map { entry in
            guard entry.id == id else { return entry }
            var toggled = entry
            toggled.isPinned.toggle()
            return toggled
        }
        return SearchHistory(entries: Self.ordered(toggled))
    }

    public func clearingUnpinned() -> SearchHistory {
        SearchHistory(entries: entries.filter(\.isPinned))
    }
}

// MARK: - Private

private extension SearchHistory {

    static func ordered(_ entries: [RecentSearch]) -> [RecentSearch] {
        let sorted = entries.enumerated()
            .sorted { lhs, rhs in
                guard lhs.element.isPinned == rhs.element.isPinned else { return lhs.element.isPinned }
                guard lhs.element.date == rhs.element.date else { return lhs.element.date > rhs.element.date }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        let pinned = sorted.filter(\.isPinned)
        let unpinned = sorted.filter { $0.isPinned == false }.prefix(unpinnedLimit)
        return pinned + unpinned
    }
}
