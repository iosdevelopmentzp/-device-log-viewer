import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FacetFilterViewModelTests {

    @Test func valuesMapCountsAndSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))

        #expect(model.title == "Category")
        #expect(model.searchPrompt == "Search category")
        #expect(model.isActive == false)
        #expect(model.hint == "Nothing is checked, so every entry is shown. Check values to show only them.")
        #expect(model.showsSearchField == false)
        #expect(model.hasValues)
        #expect(model.values(matching: "") == [
            item("default", count: 2, isSelected: false, actionTitle: "Only"),
            item("websocket", count: 1, isSelected: false, actionTitle: "Only")
        ])
        #expect(model.values(matching: "SOCK").map(\.value) == ["websocket"])
    }

    @Test func tagsGetAHashPrefix() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("tags"))

        #expect(model.values(matching: "").map(\.title) == ["#network"])
        #expect(model.values(matching: "#net").map(\.value) == ["network"])
    }

    @Test func levelsUseTheLevelTitles() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .level)

        #expect(model.title == "Level")
        #expect(model.values(matching: "").map(\.title) == ["Debug", "Info", "Notice", "Warning", "Error", "Fault"])
        #expect(model.values(matching: "").map(\.value) == ["debug", "info", "notice", "warning", "error", "fault"])
        #expect(model.values(matching: "err").map(\.count) == [1])
    }

    @Test func sourceValuesAreFileNames() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("source"))

        #expect(model.title == "Source")
        #expect(Set(model.values(matching: "").map(\.title)) == ["Sockets", "Store", "Misc"])
    }

    @Test func toggleOnlyAndClearChangeTheSession() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))
        let item = model.values(matching: "")[0]

        model.toggle(item)
        #expect(model.isActive)
        #expect(model.hint == "Only the checked values are shown.")
        #expect(model.values(matching: "")[0].isSelected)

        model.only(model.values(matching: "")[1])
        #expect(harness.session.filterState.facets[.attribute("category")] == .only(["websocket"]))

        model.clear()
        #expect(model.isActive == false)
    }

    @Test func manyValuesShowTheSearchField() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let entries = (1...9).map { "Entry \($0) INF [category\($0)] [Misc:1] 2026-10-07 22:18:54.000\n" }
        await harness.start(with: entries)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))

        #expect(model.showsSearchField)
    }

    @Test func modeOptionsAndExcludeMode() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))

        #expect(model.modeOptions == [
            FacetModeOption(mode: .include, title: "Show only checked"),
            FacetModeOption(mode: .exclude, title: "Hide checked")
        ])
        #expect(model.mode == .include)

        model.mode = .exclude
        #expect(model.mode == .exclude)
        #expect(model.isActive == false)
        #expect(model.hint == "Nothing is checked, so every entry is shown. Check values to hide them.")
        #expect(model.values(matching: "")[0].actionTitle == "Hide")
        #expect(model.values(matching: "")[0].actionHelp == "Hide only entries with this value")

        model.toggle(model.values(matching: "")[0])
        #expect(harness.session.filterState.facets[.attribute("category")] == .except(["default"]))
        #expect(model.hint == "The checked values are hidden.")
        #expect(model.values(matching: "")[0] == item("default", count: 2, isSelected: true, actionTitle: "Hide"))

        model.toggle(model.values(matching: "")[1])
        #expect(harness.session.filterState.facets[.attribute("category")] == .except(["default", "websocket"]))

        model.toggle(model.values(matching: "")[0])
        model.toggle(model.values(matching: "")[1])
        #expect(harness.session.filterState.facets[.attribute("category")] == .all)
        #expect(model.mode == .exclude)
    }

    @Test func switchingTheModeConvertsTheFilter() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))

        model.toggle(model.values(matching: "")[0])
        model.mode = .exclude
        #expect(harness.session.filterState.facets[.attribute("category")] == .except(["default"]))

        model.mode = .include
        #expect(harness.session.filterState.facets[.attribute("category")] == .only(["default"]))
    }

    @Test func onlyInExcludeModeHidesOneValue() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = FacetFilterViewModel(session: harness.session, column: .attribute("category"))
        model.mode = .exclude
        model.toggle(model.values(matching: "")[0])

        model.only(model.values(matching: "")[1])
        #expect(harness.session.filterState.facets[.attribute("category")] == .except(["websocket"]))

        model.clear()
        #expect(model.isActive == false)
        #expect(model.mode == .exclude)
    }

    private func item(_ value: String, count: Int, isSelected: Bool, actionTitle: String) -> FacetValueItem {
        FacetValueItem(
            value: value,
            title: value,
            count: count,
            countText: "\(count)",
            isSelected: isSelected,
            actionTitle: actionTitle,
            actionHelp: actionTitle == "Only" ? "Show only entries with this value" : "Hide only entries with this value"
        )
    }
}
