import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct TimeRangeViewModelTests {

    private let settings: AppSettings
    private let fixtureTime: TimeInterval = 1_791_411_534

    init() {
        settings = AppSettings(store: InMemoryKeyValueStore())
        settings.timeZoneMode = .utc
    }

    @Test func prefillsFromTheFirstAndLastVisibleRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = TimeRangeViewModel(session: harness.session, settings: settings)

        model.start()

        #expect(model.startText == "2026-10-07 22:18:54.000")
        #expect(model.endText == "2026-10-07 22:18:56.000")
        #expect(model.errorText == nil)
        #expect(model.canApply)
        #expect(model.hasTimeRange == false)
        #expect(model.hintText.contains("UTC"))
    }

    @Test func prefillsFromTheSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = TimeRangeViewModel(session: harness.session, settings: settings)

        harness.session.selectedRecords = [1]
        model.start()

        #expect(model.startText == "2026-10-07 22:18:55.000")
        #expect(model.endText == "")

        harness.session.selectedRecords = [2, 1]
        model.start()

        #expect(model.startText == "2026-10-07 22:18:55.000")
        #expect(model.endText == "2026-10-07 22:18:56.000")
    }

    @Test func prefillsFromTheCurrentRange() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [2]
        harness.session.setTimeRange(fixtureTime...(fixtureTime + 1))
        let model = TimeRangeViewModel(session: harness.session, settings: settings)

        model.start()

        #expect(model.startText == "2026-10-07 22:18:54.000")
        #expect(model.endText == "2026-10-07 22:18:55.000")
        #expect(model.hasTimeRange)
    }

    @Test func emptyFileLeavesTheTextsEmpty() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = TimeRangeViewModel(session: harness.session, settings: settings)

        model.start()

        #expect(model.startText == "")
        #expect(model.endText == "")
        #expect(model.errorText == "Cannot read the start time")
    }

    @Test func errorsBlockApply() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = TimeRangeViewModel(session: harness.session, settings: settings)
        model.start()

        model.startText = "later"
        #expect(model.errorText == "Cannot read the start time")
        #expect(model.canApply == false)
        #expect(model.apply() == false)

        model.startText = "22:18:55"
        model.endText = "soon"
        #expect(model.errorText == "Cannot read the end time")

        model.endText = "22:18:54"
        #expect(model.errorText == "Start is after end")
        #expect(model.apply() == false)
        #expect(harness.session.hasTimeRange == false)
    }

    @Test func applySetsTheRangeOnTheSessionAndClearRemovesIt() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = TimeRangeViewModel(session: harness.session, settings: settings)
        model.start()

        model.startText = "22:18:55"
        model.endText = "2026-10-07 22:18:56.000"

        #expect(model.apply())
        await harness.waitForFilter()
        #expect(harness.session.filterState.timeRange == (fixtureTime + 1)...(fixtureTime + 2))
        #expect(harness.session.visible == [1, 2])

        model.endText = " "
        #expect(model.apply())
        #expect(harness.session.filterState.timeRange == (fixtureTime + 1)...Double.greatestFiniteMagnitude)

        model.clear()
        await harness.waitForFilter()
        #expect(harness.session.hasTimeRange == false)
        #expect(harness.session.visible == [0, 1, 2])
    }
}
