import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct LogSessionTests {

    @Test func appendUpdatesVisibleAndSendsInserted() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        #expect(harness.session.visible == [0, 1, 2])
        #expect(harness.session.status == .live)
        #expect(harness.observer.events == [.inserted(0..<3)])

        await harness.send([LogFixtures.entry("More", level: "INF")])

        #expect(harness.session.visible == [0, 1, 2, 3])
        #expect(harness.observer.events.last == .inserted(3..<4))
    }

    @Test func appendCountsFacets() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        #expect(harness.session.facetCounts.count(of: "error", in: .level) == 1)
        #expect(harness.session.facetCounts.count(of: "default", in: .attribute("category")) == 2)
        #expect(harness.session.facetCounts.count(of: "network", in: .attribute("tags")) == 1)
    }

    @Test func appendWithActiveFilterAddsOnlyMatchingRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleFacetValue("error", in: .level)
        await harness.waitForFilter()
        harness.observer.removeAll()

        await harness.send([
            LogFixtures.entry("Info", level: "INF"),
            LogFixtures.entry("Second error", level: "ERR")
        ])

        #expect(harness.session.visible == [1, 4])
        #expect(harness.observer.events == [.inserted(1..<2)])
    }

    @Test func facetChangeRefiltersAndSendsReload() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.toggleFacetValue("error", in: .level)
        #expect(harness.session.isFiltering)
        await harness.waitForFilter()

        #expect(harness.session.visible == [1])
        #expect(harness.session.filterState.facets.levels == .only(["error"]))
        #expect(harness.observer.events == [.reload, .scrollToEnd])

        harness.session.showAll(in: .level)
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func excludeHidesValuesAndAddsToTheExcludedSet() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.showOnly(["error"], in: .level)
        await harness.waitForFilter()

        harness.session.exclude(["debug"], in: .level)
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets.levels == .except(["debug"]))
        #expect(harness.session.visible == [0, 1])

        harness.session.exclude(["info"], in: .level)
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets.levels == .except(["debug", "info"]))
        #expect(harness.session.visible == [1])
    }

    @Test func hideOnlyReplacesAndSetFacetModeConverts() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.exclude(["a"], in: .attribute("tags"))

        harness.session.hideOnly(["network"], in: .attribute("tags"))
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets[.attribute("tags")] == .except(["network"]))
        #expect(harness.session.visible == [1, 2])

        harness.session.setFacetMode(.include, in: .attribute("tags"))
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets[.attribute("tags")] == .only(["network"]))
        #expect(harness.session.visible == [0])

        harness.session.showAll(in: .attribute("tags"))
        harness.session.setFacetMode(.exclude, in: .attribute("tags"))
        #expect(harness.session.filterState.facets[.attribute("tags")] == .all)
    }

    @Test func searchTextFiltersInFilterMode() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.setSearchText("payment")
        await harness.waitForFilter()

        #expect(harness.session.visible == [1])
        #expect(harness.session.filterState.hasActiveFilters)
    }

    @Test func findModeKeepsAllRowsAndCollectsMatches() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.setSearchMode(.find)
        await harness.waitForFilter()
        harness.session.setSearchText("e")
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
        #expect(harness.session.findMatches == [0, 1, 2])
        #expect(harness.session.findMatchSet == [0, 1, 2])
    }

    @Test func findNextAndPreviousWrap() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample + [LogFixtures.entry("Payment retried", level: "INF")])
        harness.session.setSearchMode(.find)
        harness.session.setSearchText("payment")
        await harness.waitForFilter()
        #expect(harness.session.findMatches == [1, 3])
        harness.observer.removeAll()

        harness.session.selectedRecords = [3]
        harness.session.findNext()
        harness.session.selectedRecords = [1]
        harness.session.findPrevious()

        #expect(harness.observer.events == [.select(row: 1), .select(row: 3)])
        #expect(harness.session.findPosition == 0)
        #expect(harness.session.isFollowing == false)
    }

    @Test func bookmarksLoadOnStartAndPersistOnToggle() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let payment = try #require(harness.session.record(at: 1))
        harness.observer.removeAll()

        harness.session.toggleBookmarks(recordIndices: [1])

        #expect(harness.session.isBookmarked(payment))
        #expect(harness.repository.bookmarks(for: LogFixtures.url) == [payment.offset])
        #expect(harness.observer.events == [.refreshRows])

        harness.session.toggleBookmarks(recordIndices: [1])

        #expect(harness.repository.bookmarks(for: LogFixtures.url).isEmpty)
    }

    @Test func storedBookmarksAreLoadedAndNavigated() async throws {
        var fixtures = LogFixtures()
        let offsets = Set(fixtures.batch(LogFixtures.sample).records.map(\.offset))
        var harness = SessionHarness(bookmarks: offsets, debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.selectedRecords = [2]
        harness.session.nextBookmark()
        harness.session.selectedRecords = [0]
        harness.session.previousBookmark()

        #expect(harness.session.bookmarks == offsets)
        #expect(harness.observer.events == [.select(row: 0), .select(row: 2)])
    }

    @Test func bookmarksOnlyShowsBookmarkedRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleBookmarks(recordIndices: [2])

        harness.session.setBookmarksOnly(true)
        await harness.waitForFilter()
        #expect(harness.session.visible == [2])

        harness.session.toggleBookmarks(recordIndices: [0])
        await harness.waitForFilter()
        #expect(harness.session.visible == [0, 2])
    }

    @Test func clearBookmarksEmptiesAndPersistsAndRefreshesRows() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleBookmarks(recordIndices: [0, 2])
        harness.observer.removeAll()

        harness.session.clearBookmarks()

        #expect(harness.session.bookmarks.isEmpty)
        #expect(harness.repository.bookmarks(for: LogFixtures.url).isEmpty)
        #expect(harness.observer.events == [.refreshRows])
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func clearBookmarksRefiltersWhenBookmarksOnlyIsOn() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleBookmarks(recordIndices: [1])
        harness.session.setBookmarksOnly(true)
        await harness.waitForFilter()
        #expect(harness.session.visible == [1])

        harness.session.clearBookmarks()
        await harness.waitForFilter()

        #expect(harness.session.visible.isEmpty)
        #expect(harness.session.bookmarks.isEmpty)
    }

    @Test func clearBookmarksWithoutBookmarksDoesNothing() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.clearBookmarks()

        #expect(harness.observer.events.isEmpty)
    }

    @Test func resetClearsContentBookmarksAndCounts() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleBookmarks(recordIndices: [0])
        harness.session.selectedRecords = [1]
        harness.observer.removeAll()

        harness.source.send(.reset)
        await Eventually.wait { harness.session.content.records.isEmpty }

        #expect(harness.session.visible.isEmpty)
        #expect(harness.session.bookmarks.isEmpty)
        #expect(harness.session.selectedRecords.isEmpty)
        #expect(harness.session.facetCounts == FacetCounts(profile: LogFixtures.profile))
        #expect(harness.repository.bookmarks(for: LogFixtures.url).isEmpty)
        #expect(harness.observer.events == [.reload])
    }

    @Test func missingEventSetsStatus() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.source.send(.missing)
        await Eventually.wait { harness.session.status == .missing }
    }

    @Test func newEntriesWhileDetachedGrowOnlyWhenNotFollowing() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        #expect(harness.session.newEntriesWhileDetached == 0)

        harness.session.isFollowing = false
        await harness.send([LogFixtures.entry("One", level: "INF"), LogFixtures.entry("Two", level: "INF")])
        #expect(harness.session.newEntriesWhileDetached == 2)

        harness.session.jumpToEnd()
        #expect(harness.session.newEntriesWhileDetached == 0)
        #expect(harness.observer.events.last == .scrollToEnd)

        await harness.send([LogFixtures.entry("Three", level: "INF")])
        #expect(harness.session.newEntriesWhileDetached == 0)
    }

    @Test func goToEntryClampsToTheLog() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.goToEntry(number: 0)
        harness.session.goToEntry(number: 2)
        harness.session.goToEntry(number: 99)

        #expect(harness.observer.events == [.select(row: 0), .select(row: 1), .select(row: 2)])
    }

    @Test func selectPicksTheNearestVisibleRow() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleFacetValue("debug", in: .level)
        harness.session.toggleFacetValue("info", in: .level)
        await harness.waitForFilter()
        harness.observer.removeAll()

        harness.session.select(recordIndex: 1)

        #expect(harness.session.visible == [0, 2])
        #expect(harness.observer.events == [.select(row: 1)])
    }

    @Test func showInFullLogClearsFiltersAndRestoresSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleFacetValue("error", in: .level)
        harness.session.setSearchText("payment")
        await harness.waitForFilter()
        harness.observer.removeAll()

        harness.session.showInFullLog(recordIndex: 1)
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
        #expect(harness.session.selectedRecords == [1])
        #expect(harness.session.filterState.hasActiveFilters == false)
        #expect(harness.observer.events == [.reload, .select(row: 1)])
    }

    @Test func recordsAddedDuringAFilterRunAreFilteredAfterIt() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(100))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.setSearchText("fail")
        await harness.send([LogFixtures.entry("Late failure", level: "ERR")])
        #expect(harness.session.isFiltering)
        #expect(harness.session.visible == [0, 1, 2])
        await harness.waitForFilter()

        #expect(harness.session.visible == [1, 3])
        #expect(harness.observer.events == [.reload, .inserted(1..<2), .scrollToEnd])
    }

    @Test func textChangeIsDebouncedAndSupersededRunsAreDropped() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(50))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.setSearchText("pay")
        harness.session.setSearchText("debug")
        await harness.waitForFilter()

        #expect(harness.session.visible == [2])
        #expect(harness.observer.events == [.reload, .scrollToEnd])
    }

    @Test func searchScopeChangeRefiltersOnlyWithText() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.toggleSearchScope("tags")
        #expect(harness.session.isFiltering == false)
        #expect(harness.session.filterState.searchScope == SearchScope(ids: ["message", "tags"]))

        harness.session.setSearchText("network")
        await harness.waitForFilter()
        #expect(harness.session.visible == [0])

        harness.session.toggleSearchScope("tags")
        #expect(harness.session.isFiltering)
        await harness.waitForFilter()
        #expect(harness.session.visible.isEmpty)
    }

    @Test func searchScopeCannotBecomeEmpty() async {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        harness.session.toggleSearchScope("message")

        #expect(harness.session.filterState.searchScope == .message)
    }

    @Test func stopStopsTheSource() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.stop()

        #expect(harness.source.isStopped)
    }

    @Test func rowAccessorsReadVisibleRecords() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [0, 2]

        #expect(harness.session.record(atRow: 1)?.message == "Payment failed")
        #expect(harness.session.recordIndex(atRow: 5) == nil)
        #expect(harness.session.previousRecord(before: 0) == nil)
        #expect(harness.session.primarySelection?.message == "Debug noise")
        let payment = try #require(harness.session.record(at: 1))
        #expect(harness.session.text(of: payment).hasPrefix("Payment failed ERR"))
    }

    @Test func applyFacetsSetsFacetsAndBookmarksOnlyInOneRefilter() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()
        var facets = FacetSelection.all
        facets[.level] = .except(["debug"])

        harness.session.applyFacets(facets, bookmarksOnly: false)
        await harness.waitForFilter()

        #expect(harness.session.filterState.facets == facets)
        #expect(harness.session.filterState.bookmarksOnly == false)
        #expect(harness.session.visible == [0, 1])
        #expect(harness.observer.events == [.reload, .scrollToEnd])

        harness.observer.removeAll()
        harness.session.applyFacets(facets, bookmarksOnly: false)
        #expect(harness.session.isFiltering == false)
        #expect(harness.observer.events.isEmpty)
    }

    @Test func applyPresetReplacesTheWholeStateInOneRefilter() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.setBookmarksOnly(true)
        await harness.waitForFilter()
        harness.observer.removeAll()
        var facets = FacetSelection.all
        facets[.level] = .except(["debug"])
        let preset = FilterPreset(
            id: UUID(),
            name: "Find",
            searchText: "Payment",
            searchMode: .find,
            searchScope: SearchScope(ids: ["message", "source"]),
            isRegex: false,
            facets: facets,
            bookmarksOnly: false,
            extraTerms: []
        )

        harness.session.apply(preset)
        await harness.waitForFilter()

        #expect(harness.session.filterState == LogFilterState(preset: preset))
        #expect(harness.session.visible == [0, 1])
        #expect(harness.session.findMatches == [1])
        #expect(harness.observer.events == [.reload, .scrollToEnd])

        harness.observer.removeAll()
        harness.session.apply(preset)
        #expect(harness.session.isFiltering == false)
        #expect(harness.observer.events.isEmpty)
    }

    @Test func clearAllEntriesHidesEarlierRecordsAndNewRecordsStillAppear() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.clearAllEntries()
        await harness.waitForFilter()

        #expect(harness.session.hasClearedEntries)
        #expect(harness.session.filterState.markIndex == 3)
        #expect(harness.session.filterState.hasActiveFilters)
        #expect(harness.session.visible.isEmpty)
        #expect(harness.session.clearedCounts == (before: 3, after: 0, selected: 0))

        await harness.send([LogFixtures.entry("After clear", level: "INF")])

        #expect(harness.session.visible == [3])

        harness.session.restoreBefore()
        await harness.waitForFilter()

        #expect(harness.session.hasClearedEntries == false)
        #expect(harness.session.visible == [0, 1, 2, 3])
    }

    @Test func clearAllEntriesOnAnEmptyFileStillCounts() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        harness.session.clearAllEntries()

        #expect(harness.session.filterState.markIndex == 0)
        #expect(harness.session.filterState.hasActiveFilters)
    }

    @Test func clearAllEntriesReplacesTheOtherClearedParts() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearEntries(after: 0)
        harness.session.clearEntries(recordIndices: [0])

        harness.session.clearAllEntries()
        await harness.waitForFilter()
        await harness.send([LogFixtures.entry("After clear", level: "INF")])

        #expect(harness.session.filterState.clearedAfterRange == nil)
        #expect(harness.session.filterState.clearedOffsets.isEmpty)
        #expect(harness.session.visible == [3])
    }

    @Test func clearEntriesBeforeKeepsTheRecordItself() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.clearEntries(before: 2)
        harness.session.clearEntries(before: 1)
        await harness.waitForFilter()

        #expect(harness.session.filterState.markIndex == 1)
        #expect(harness.session.visible == [1, 2])
        #expect(harness.session.clearedCounts.before == 1)
    }

    @Test func clearEntriesAfterHidesOnlyExistingLaterRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(after: 0)
        await harness.waitForFilter()

        #expect(harness.session.filterState.clearedAfterRange == 1..<3)
        #expect(harness.session.visible == [0])
        #expect(harness.session.clearedCounts.after == 2)

        harness.session.restoreAfter()
        await harness.waitForFilter()

        #expect(harness.session.filterState.clearedAfterRange == nil)
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func recordsAppendedAfterClearEntriesAfterStayVisible() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.clearEntries(after: 0)
        await harness.waitForFilter()
        await harness.send([LogFixtures.entry("Visible", level: "INF")])

        #expect(harness.session.filterState.clearedAfterRange == 1..<3)
        #expect(harness.session.visible == [0, 3])
        #expect(harness.session.clearedCounts.after == 2)
    }

    @Test func clearEntriesAfterTheLastRecordClearsNothing() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.clearEntries(after: 2)

        #expect(harness.session.filterState.clearedAfterRange == nil)
        #expect(harness.session.hasClearedEntries == false)
    }

    @Test func clearAroundSelectionNeedsOneSelectedRecord() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.session.selectedRecords = [0, 1]
        harness.session.clearEntriesBeforeSelection()
        harness.session.clearEntriesAfterSelection()
        #expect(harness.session.hasClearedEntries == false)

        harness.session.selectedRecords = [1]
        harness.session.clearEntriesBeforeSelection()
        harness.session.clearEntriesAfterSelection()
        await harness.waitForFilter()

        #expect(harness.session.filterState.markIndex == 1)
        #expect(harness.session.filterState.clearedAfterRange == 2..<3)
        #expect(harness.session.visible == [1])
    }

    @Test func clearSelectedEntriesHidesThemAndEmptiesTheSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let offsets = harness.session.content.records.map(\.offset)

        harness.session.selectedRecords = [0, 2]
        harness.session.clearSelectedEntries()
        await harness.waitForFilter()

        #expect(harness.session.selectedRecords.isEmpty)
        #expect(harness.session.filterState.clearedOffsets == [offsets[0], offsets[2]])
        #expect(harness.session.visible == [1])
        #expect(harness.session.clearedCounts.selected == 2)

        harness.session.clearSelectedEntries()
        #expect(harness.session.clearedCounts.selected == 2)

        harness.session.restoreSelected()
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func restoreAllEntriesBringsEveryPartBack() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearEntries(before: 1)
        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(recordIndices: [1])
        await harness.waitForFilter()
        #expect(harness.session.visible.isEmpty)

        harness.session.restoreAllEntries()
        await harness.waitForFilter()

        #expect(harness.session.hasClearedEntries == false)
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func resetDropsClearedEntries() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearEntries(before: 1)
        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(recordIndices: [1])
        await harness.waitForFilter()

        harness.source.send(.reset)
        await Eventually.wait { harness.session.content.records.isEmpty }

        #expect(harness.session.hasClearedEntries == false)
    }

    @Test func clearFiltersRestoresClearedEntriesAndRemovesTheTimeRange() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearAllEntries()
        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(recordIndices: [0])
        harness.session.setTimeRange(0...1)
        await harness.waitForFilter()

        harness.session.clearFilters()
        await harness.waitForFilter()

        #expect(harness.session.hasClearedEntries == false)
        #expect(harness.session.hasTimeRange == false)
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func showInFullLogRestoresClearedEntries() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearEntries(before: 2)
        await harness.waitForFilter()

        harness.session.showInFullLog(recordIndex: 2)
        await harness.waitForFilter()

        #expect(harness.session.hasClearedEntries == false)
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func timeRangeKeepsOnlyRecordsInside() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let first = try #require(harness.session.record(at: 0)?.timestamp)

        harness.session.setTimeRange((first + 0.5)...(first + 1.5))
        await harness.waitForFilter()

        #expect(harness.session.hasTimeRange)
        #expect(harness.session.visible == [1])

        harness.session.clearTimeRange()
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func timeRangeFromOneSelectedRecordHasAnOpenEnd() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let second = try #require(harness.session.record(at: 1)?.timestamp)

        harness.session.selectedRecords = [1]
        harness.session.setTimeRangeFromSelection()
        await harness.waitForFilter()

        #expect(harness.session.filterState.timeRange == second...Double.greatestFiniteMagnitude)
        #expect(harness.session.visible == [1, 2])
    }

    @Test func timeRangeFromTwoSelectedRecordsUsesMinAndMax() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let first = try #require(harness.session.record(at: 0)?.timestamp)
        let second = try #require(harness.session.record(at: 1)?.timestamp)

        harness.session.selectedRecords = [1, 0]
        harness.session.setTimeRangeFromSelection()
        await harness.waitForFilter()

        #expect(harness.session.filterState.timeRange == first...second)
        #expect(harness.session.visible == [0, 1])
    }

    @Test func timeRangeFromSelectionWithoutTimestampsDoesNothing() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: ["Plain text without a header\n"])

        harness.session.setTimeRangeFromSelection()
        #expect(harness.session.hasTimeRange == false)

        harness.session.selectedRecords = [0]
        harness.session.setTimeRangeFromSelection()
        #expect(harness.session.hasTimeRange == false)
    }

    @Test func applyPresetKeepsClearedEntriesAndClearsTheTimeRange() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.clearEntries(before: 1)
        harness.session.clearEntries(after: 1)
        harness.session.clearEntries(recordIndices: [0])
        harness.session.setTimeRange(0...1)
        await harness.waitForFilter()
        let cleared = harness.session.filterState
        let preset = LogFilterState(searchScope: .message, isRegex: false).makePreset(name: "Errors")

        harness.session.apply(preset)
        await harness.waitForFilter()

        #expect(harness.session.filterState.markIndex == cleared.markIndex)
        #expect(harness.session.filterState.clearedAfterRange == cleared.clearedAfterRange)
        #expect(harness.session.filterState.clearedOffsets == cleared.clearedOffsets)
        #expect(harness.session.hasTimeRange == false)
        #expect(harness.session.visible == [1])
    }

    @Test func extraTermsNarrowTheVisibleRows() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.observer.removeAll()

        harness.session.addExtraTerm()

        #expect(harness.session.filterState.extraTerms == [SearchTerm(text: "", isNegated: false)])
        #expect(harness.session.isFiltering == false)
        #expect(harness.observer.events.isEmpty)

        harness.session.updateExtraTerm(at: 0, text: "payment")
        await harness.waitForFilter()

        #expect(harness.session.visible == [1])

        harness.session.setExtraTermNegated(at: 0, true)
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 2])

        harness.session.removeExtraTerm(at: 0)
        await harness.waitForFilter()

        #expect(harness.session.filterState.extraTerms.isEmpty)
        #expect(harness.session.visible == [0, 1, 2])
    }

    @Test func extraTermsLimitFindMatches() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.setSearchMode(.find)
        harness.session.setSearchText("e")
        harness.session.setExtraTerms([SearchTerm(text: "noise", isNegated: true)])
        await harness.waitForFilter()

        #expect(harness.session.visible == [0, 1, 2])
        #expect(harness.session.findMatches == [0, 1])
    }

    @Test func addExtraTermStopsAtThree() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        for _ in 0..<5 {
            harness.session.addExtraTerm()
        }

        #expect(harness.session.filterState.extraTerms.count == 3)
    }

    @Test func extraTermIndexOutOfRangeIsIgnored() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        harness.session.updateExtraTerm(at: 2, text: "x")
        harness.session.setExtraTermNegated(at: 2, true)
        harness.session.removeExtraTerm(at: 2)

        #expect(harness.session.filterState.extraTerms.isEmpty)
    }
}
