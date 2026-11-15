import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FilterMenuViewModelTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())

    @Test func togglingALevelSelectsOnlyThatLevel() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterMenuViewModel(session: harness.session, settings: settings)

        #expect(model.isAllLevels)
        #expect(model.levelOptions.map(\.title) == ["Debug", "Info", "Notice", "Warning", "Error", "Fault"])
        #expect(model.symbolName == "line.3.horizontal.decrease.circle")

        model.toggle(levelID: "error")

        #expect(model.levelOptions.first { $0.id == "error" } == LevelOption(id: "error", title: "Error", style: .red, isOn: true))
        #expect(model.levelOptions.filter(\.isOn).count == 1)
        #expect(harness.session.filterState.facets.levels == .only(["error"]))
        #expect(model.hasActiveFilters)
        #expect(model.symbolName == "line.3.horizontal.decrease.circle.fill")
    }

    @Test func presetsSetTheLevels() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterMenuViewModel(session: harness.session, settings: settings)

        #expect(model.alertLevelsTitle == "Error and Fault Only")
        #expect(model.highlightedLevelsTitle == "Warning and Above")
        model.showAlertLevels()
        #expect(harness.session.filterState.facets.levels == .only(["error", "fault"]))
        model.showHighlightedAndAbove()
        #expect(harness.session.filterState.facets.levels == .only(["warning", "error", "fault"]))
        model.showAllLevels()
        #expect(model.isAllLevels)
    }

    @Test func profileWithoutAlertsOrHighlightsHasNoPresets() {
        var profile = ProfileFixtures.textTrailing
        profile.levels = profile.levels.map { level in
            var level = level
            level.alerts = false
            level.highlightsRow = false
            return level
        }
        let session = LogSession(
            url: LogFixtures.url,
            profile: profile,
            source: FakeLogSource(url: LogFixtures.url),
            bookmarkRepository: FakeBookmarkRepository(stored: [:]),
            filterRunner: LogFilterRunner(debounce: .milliseconds(1)),
            searchScope: .message,
            isRegex: false
        )
        let model = FilterMenuViewModel(session: session, settings: settings)

        #expect(model.alertLevelsTitle == nil)
        #expect(model.highlightedLevelsTitle == nil)
        model.showAlertLevels()
        model.showHighlightedAndAbove()
        #expect(model.isAllLevels)
    }

    @Test func bookmarksOnlyAndClear() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterMenuViewModel(session: harness.session, settings: settings)

        model.bookmarksOnly = true
        #expect(harness.session.filterState.bookmarksOnly)
        #expect(model.hasActiveFilters)

        model.clearFilters()
        #expect(model.bookmarksOnly == false)
        #expect(model.hasActiveFilters == false)
    }

    @Test func recentFiltersAreListedAndApplied() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterMenuViewModel(session: harness.session, settings: settings)
        #expect(model.hasRecentFilters == false)
        #expect(model.recentFilterItems.isEmpty)

        var facets = FacetSelection.all
        facets[.level] = .only(["error"])
        facets[.attribute("tags")] = .only(["network"])
        let entry = RecentFilterSet(id: UUID(), facets: facets, bookmarksOnly: true, date: Date())
        settings.filterHistory = settings.filterHistory.adding(entry)

        #expect(model.hasRecentFilters)
        #expect(model.recentFilterItems == [RecentFilterItem(id: entry.id, title: "ERR · #network · Bookmarks")])

        model.applyRecentFilter(id: entry.id)
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets == facets)
        #expect(harness.session.filterState.bookmarksOnly)
    }

    @Test func timeRangeActions() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterMenuViewModel(session: harness.session, settings: settings)

        #expect(model.hasTimeRange == false)

        harness.session.setTimeRange(0...1)
        #expect(model.hasTimeRange)

        model.clearTimeRange()
        #expect(model.hasTimeRange == false)
    }

    @Test func clearActions() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterMenuViewModel(session: harness.session, settings: settings)

        #expect(model.hasClearedEntries == false)
        #expect(model.canClearAroundSelection == false)
        #expect(model.canClearSelection == false)

        model.clearAllEntries()
        #expect(model.hasClearedEntries)
        #expect(harness.session.filterState.markIndex == 3)

        model.restoreAllEntries()
        #expect(model.hasClearedEntries == false)

        harness.session.selectedRecords = [1]
        #expect(model.canClearAroundSelection)
        #expect(model.canClearSelection)
        model.clearEntriesBeforeSelection()
        model.clearEntriesAfterSelection()
        #expect(harness.session.filterState.markIndex == 1)
        #expect(harness.session.filterState.clearedAfterRange == 2..<3)

        harness.session.selectedRecords = [0, 2]
        #expect(model.canClearAroundSelection == false)
        model.clearSelectedEntries()
        #expect(harness.session.clearedCounts.selected == 2)
        #expect(model.canClearSelection == false)
    }
}
