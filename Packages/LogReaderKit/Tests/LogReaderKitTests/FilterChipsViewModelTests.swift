import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FilterChipsViewModelTests {

    private let settings: AppSettings

    init() {
        settings = AppSettings(store: InMemoryKeyValueStore())
        settings.timeZoneMode = .utc
    }

    @Test func passThroughStateHasNoChips() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        #expect(model.chips.isEmpty)
        #expect(model.isEmpty)
    }

    @Test func filterModeSearchChip() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        harness.session.setSearchText("payment")

        #expect(model.chips == [FilterChipItem(id: "search", title: "Filter: payment", kind: .search, isExclusion: false)])
        #expect(model.isEmpty == false)
    }

    @Test func findModeChipShowsTheMatchCount() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterChipsViewModel(session: harness.session, settings: settings)
        harness.session.setSearchMode(.find)

        harness.session.setSearchText("e")
        await harness.waitForFilter()
        #expect(model.chips.map(\.title) == ["Find: e (3 matches)"])

        harness.session.setSearchText("zzz")
        await harness.waitForFilter()
        #expect(model.chips.map(\.title) == ["Find: zzz (no matches)"])
    }

    @Test func levelsChipInIncludeAndExcludeMode() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        harness.session.setLevels(.only(["fault", "error"]))
        #expect(model.chips == [FilterChipItem(id: "levels", title: "Level: ERR, FLT", kind: .levels, isExclusion: false)])

        harness.session.setLevels(.except(["debug"]))
        #expect(model.chips == [FilterChipItem(id: "levels", title: "Not level: DBG", kind: .levels, isExclusion: true)])
    }

    @Test func facetChipsShowAtMostThreeValues() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        harness.session.showOnly(["network", "api", "auth", "ui"], in: .attribute("tags"))
        harness.session.hideOnly(["ApiService"], in: .attribute("source"))
        harness.session.showOnly(["default"], in: .attribute("category"))

        #expect(model.chips.map(\.title) == ["Tags: #api, #auth, #network +1", "Category: default", "Not source: ApiService"])
        #expect(model.chips.map(\.isExclusion) == [false, false, true])
    }

    @Test func chipsFollowTheFixedOrder() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        harness.session.setBookmarksOnly(true)
        harness.session.showOnly(["api"], in: .attribute("tags"))
        harness.session.setLevels(.only(["error"]))
        harness.session.setSearchText("x")

        #expect(model.chips.map(\.kind) == [.search, .levels, .facet(.attribute("tags")), .bookmarks])
        #expect(model.chips.last?.title == "Bookmarks only")
    }

    @Test func removeClearsOnlyThatPart() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)
        harness.session.setSearchText("x")
        harness.session.setLevels(.only(["error"]))
        harness.session.showOnly(["api"], in: .attribute("tags"))
        harness.session.setBookmarksOnly(true)

        model.remove(chip(.levels, in: model))
        #expect(harness.session.filterState.facets.levels == .all)
        #expect(model.chips.map(\.kind) == [.search, .facet(.attribute("tags")), .bookmarks])

        model.remove(chip(.facet(.attribute("tags")), in: model))
        #expect(harness.session.filterState.facets[.attribute("tags")] == .all)
        #expect(model.chips.map(\.kind) == [.search, .bookmarks])

        model.remove(chip(.bookmarks, in: model))
        #expect(harness.session.filterState.bookmarksOnly == false)
        #expect(model.chips.map(\.kind) == [.search])

        model.remove(chip(.search, in: model))
        #expect(harness.session.filterState.searchText.isEmpty)
        #expect(model.isEmpty)
    }

    @Test func clearAllRemovesEveryChip() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = FilterChipsViewModel(session: harness.session, settings: settings)
        harness.session.setSearchText("x")
        harness.session.setLevels(.except(["debug"]))
        harness.session.hideOnly(["default"], in: .attribute("category"))
        harness.session.setBookmarksOnly(true)

        model.clearAll()

        #expect(model.isEmpty)
        #expect(harness.session.filterState.facets == .all)
    }

    @Test func timeRangeChipAndItsRemoval() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterChipsViewModel(session: harness.session, settings: settings)
        let start: TimeInterval = 1_791_411_534.787

        harness.session.setTimeRange(start...(start + 35.213))

        #expect(chip(.timeRange, in: model).title == "Time: 22:18:54.787 – 22:19:30.000")
        #expect(model.chips.last?.kind == .timeRange)

        model.remove(chip(.timeRange, in: model))
        #expect(harness.session.hasTimeRange == false)
        #expect(model.isEmpty)
    }

    @Test func clearedEntriesGiveNoChip() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FilterChipsViewModel(session: harness.session, settings: settings)

        harness.session.clearAllEntries()
        harness.session.clearEntries(after: 1)

        #expect(harness.session.filterState.hasActiveFilters)
        #expect(model.chips.isEmpty)
        #expect(model.isEmpty)
    }

    @Test func groupedNumbersUseSpaces() {
        #expect(GroupedNumberText.text(1_234) == "1 234")
        #expect(GroupedNumberText.text(12) == "12")
        #expect(GroupedNumberText.text(1_234_567) == "1 234 567")
    }
}

// MARK: - Private

private extension FilterChipsViewModelTests {

    func chip(_ kind: FilterChipItem.Kind, in model: FilterChipsViewModel) -> FilterChipItem {
        guard let chip = model.chips.first(where: { $0.kind == kind }) else {
            Issue.record("No chip of kind \(kind)")
            return FilterChipItem(id: "", title: "", kind: kind, isExclusion: false)
        }
        return chip
    }
}
