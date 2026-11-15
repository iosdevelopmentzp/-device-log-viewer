import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct FilterHistoryTests {

    @Test func equalFilterSetMovesToTheTopAndKeepsItsID() {
        let errors = Self.filterSet(levels: .only(["error"]), bookmarksOnly: false, at: 1)
        let history = FilterHistory.empty
            .adding(errors)
            .adding(Self.filterSet(levels: .only(["warning"]), bookmarksOnly: false, at: 2))
            .adding(Self.filterSet(levels: .only(["error"]), bookmarksOnly: false, at: 3))

        #expect(history.entries.count == 2)
        #expect(history.entries.first?.id == errors.id)
        #expect(history.entries.first?.date == Date(timeIntervalSince1970: 3))
        #expect(history.entries.last?.facets.levels == .only(["warning"]))
    }

    @Test func bookmarksOnlyMakesADifferentFilterSet() {
        let history = FilterHistory.empty
            .adding(Self.filterSet(levels: .only(["error"]), bookmarksOnly: false, at: 1))
            .adding(Self.filterSet(levels: .only(["error"]), bookmarksOnly: true, at: 2))

        #expect(history.entries.count == 2)
    }

    @Test func capKeepsTheTenNewest() {
        var history = FilterHistory.empty
        for index in 0..<12 {
            var facets = FacetSelection.all
            facets[.attribute("tags")] = .only(["t\(index)"])
            history = history.adding(RecentFilterSet(id: UUID(), facets: facets, bookmarksOnly: false, date: Date()))
        }

        #expect(history.entries.count == 10)
        #expect(history.entries.first?.facets[.attribute("tags")] == .only(["t11"]))
        #expect(history.entries.last?.facets[.attribute("tags")] == .only(["t2"]))
    }

    @Test func filterSetDecodesTheLegacyLevelNumbers() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","facets":{"levels":{"only":{"_0":[4,5]}}},"bookmarksOnly":false,"date":0}"#

        let entry = try JSONDecoder().decode(RecentFilterSet.self, from: Data(json.utf8))

        #expect(entry.facets.levels == .only(["error", "fault"]))
    }

    @Test func removingDropsTheEntry() {
        let entry = Self.filterSet(levels: .only(["error"]), bookmarksOnly: false, at: 1)
        let history = FilterHistory.empty.adding(entry)

        #expect(history.entry(id: entry.id) == entry)
        #expect(history.removing(id: entry.id) == .empty)
    }
}

// MARK: - Private

private extension FilterHistoryTests {

    static func filterSet(levels: FacetFilter<String>, bookmarksOnly: Bool, at time: TimeInterval) -> RecentFilterSet {
        var facets = FacetSelection.all
        facets[.level] = levels
        return RecentFilterSet(
            id: UUID(),
            facets: facets,
            bookmarksOnly: bookmarksOnly,
            date: Date(timeIntervalSince1970: time)
        )
    }
}
