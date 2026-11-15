import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct ClearedEntriesViewModelTests {

    @Test func nothingClearedIsInactive() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = ClearedEntriesViewModel(session: harness.session)

        #expect(model.isActive == false)
        #expect(model.parts.isEmpty)
    }

    @Test func summaryAndPartsUseEntryNumbers() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample + [LogFixtures.entry("Fourth", level: "INF")])
        let model = ClearedEntriesViewModel(session: harness.session)

        harness.session.clearEntries(before: 1)
        harness.session.clearEntries(after: 2)
        harness.session.clearEntries(recordIndices: [1])
        await harness.waitForFilter()

        #expect(model.isActive)
        #expect(model.summaryText == "Showing 1 of 4 entries")
        #expect(model.parts.map(\.title) == [
            "1 cleared before #2",
            "1 cleared after #3",
            "1 selected entry cleared"
        ])
        #expect(model.parts.map(\.kind) == [.before, .after, .selected])
    }

    @Test func clearedAfterCountStaysWhenNewEntriesArrive() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = ClearedEntriesViewModel(session: harness.session)

        harness.session.clearEntries(after: 0)
        harness.session.clearEntries(recordIndices: [0])
        await harness.waitForFilter()
        await harness.send([LogFixtures.entry("New", level: "INF")])

        #expect(model.parts.map(\.title) == ["2 cleared after #1", "1 selected entry cleared"])

        harness.session.restoreSelected()
        harness.session.selectedRecords = [1, 2]
        harness.session.clearEntries(after: 2)
        harness.session.clearSelectedEntries()

        #expect(model.parts.map(\.title) == ["1 cleared after #3", "2 selected entries cleared"])
    }

    @Test func restorePartRestoresOnlyThatPart() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = ClearedEntriesViewModel(session: harness.session)
        harness.session.clearEntries(before: 1)
        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(recordIndices: [1])

        model.restore(part: try #require(model.parts.first { $0.kind == .after }))
        #expect(harness.session.filterState.clearedAfterRange == nil)
        #expect(harness.session.filterState.markIndex == 1)

        model.restore(part: try #require(model.parts.first { $0.kind == .before }))
        #expect(harness.session.filterState.markIndex == nil)

        model.restore(part: try #require(model.parts.first { $0.kind == .selected }))
        #expect(model.isActive == false)
    }

    @Test func restoreAllRestoresEveryPart() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = ClearedEntriesViewModel(session: harness.session)
        harness.session.clearAllEntries()
        harness.session.clearEntries(recordIndices: [1])

        model.restoreAll()
        await harness.waitForFilter()

        #expect(model.isActive == false)
        #expect(harness.session.visible == [0, 1, 2])
    }

}
