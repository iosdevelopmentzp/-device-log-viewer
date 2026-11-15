import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct SearchHistoryTests {

    @Test func addingPutsTheNewestFirst() {
        let history = SearchHistory.empty
            .adding(Self.search("a", mode: .filter, scope: .message, at: 1))
            .adding(Self.search("b", mode: .filter, scope: .message, at: 2))

        #expect(history.entries.map(\.text) == ["b", "a"])
    }

    @Test func addingAnEqualSearchMovesItToTheTopAndKeepsItsPin() {
        let first = Self.search("a", mode: .filter, scope: .message, at: 1)
        var history = SearchHistory.empty
            .adding(first)
            .adding(Self.search("b", mode: .filter, scope: .message, at: 2))
            .togglingPin(id: first.id)
            .adding(Self.search("c", mode: .filter, scope: .message, at: 3))

        history = history.adding(Self.search("a", mode: .filter, scope: .message, at: 4))

        #expect(history.entries.map(\.text) == ["a", "c", "b"])
        #expect(history.entries.first?.id == first.id)
        #expect(history.entries.first?.isPinned == true)
        #expect(history.entries.first?.date == Date(timeIntervalSince1970: 4))
    }

    @Test func differentModeOrScopeIsADifferentSearch() {
        let history = SearchHistory.empty
            .adding(Self.search("a", mode: .filter, scope: .message, at: 1))
            .adding(Self.search("a", mode: .find, scope: .message, at: 2))
            .adding(Self.search("a", mode: .filter, scope: SearchScope(ids: ["message", "tags"]), at: 3))

        #expect(history.entries.count == 3)
    }

    @Test func pinnedEntriesComeFirst() {
        let old = Self.search("old", mode: .filter, scope: .message, at: 1)
        let history = SearchHistory.empty
            .adding(old)
            .adding(Self.search("new", mode: .filter, scope: .message, at: 2))
            .togglingPin(id: old.id)

        #expect(history.entries.map(\.text) == ["old", "new"])
        #expect(history.togglingPin(id: old.id).entries.map(\.text) == ["new", "old"])
    }

    @Test func capKeepsThirtyUnpinnedAndAllPinned() {
        let pinned = Self.search("pinned", mode: .filter, scope: .message, at: 0)
        var history = SearchHistory.empty.adding(pinned).togglingPin(id: pinned.id)
        for index in 1...40 {
            history = history.adding(Self.search("s\(index)", mode: .filter, scope: .message, at: TimeInterval(index)))
        }

        #expect(history.entries.count == 31)
        #expect(history.entries.first?.text == "pinned")
        #expect(history.entries[1].text == "s40")
        #expect(history.entries.last?.text == "s11")
    }

    @Test func removingDropsTheEntry() {
        let entry = Self.search("a", mode: .filter, scope: .message, at: 1)
        let history = SearchHistory.empty.adding(entry).adding(Self.search("b", mode: .filter, scope: .message, at: 2))

        #expect(history.removing(id: entry.id).entries.map(\.text) == ["b"])
        #expect(history.entry(id: entry.id) == entry)
    }

    @Test func clearingKeepsPinnedEntries() {
        let pinned = Self.search("a", mode: .filter, scope: .message, at: 1)
        let history = SearchHistory.empty
            .adding(pinned)
            .adding(Self.search("b", mode: .filter, scope: .message, at: 2))
            .togglingPin(id: pinned.id)
            .clearingUnpinned()

        #expect(history.entries.map(\.text) == ["a"])
    }
}

// MARK: - Private

private extension SearchHistoryTests {

    static func search(_ text: String, mode: SearchMode, scope: SearchScope, at time: TimeInterval) -> RecentSearch {
        RecentSearch(
            id: UUID(),
            text: text,
            mode: mode,
            scope: scope,
            isRegex: false,
            date: Date(timeIntervalSince1970: time),
            isPinned: false
        )
    }
}
