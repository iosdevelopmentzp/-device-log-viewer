import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct RowContextMenuModelTests {

    private let pasteboard = FakePasteboard()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let index = FakeSourceFileIndex()
    private let opener = FakeSourceOpener()

    @Test func singleRowItems() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        let entries = makeEntries(harness.session, recordIndices: [0], showDetails: {})

        #expect(Self.titles(entries) == [
            "Copy Entry", "Copy Message", "Copy as JSON", "Copy Source “Sockets:10”", "-",
            "Add Bookmark", "Show Details", "Open in Xcode", "Show Only From This Entry", "-",
            "Clear Entries Before This", "Clear Entries After This", "Clear Selected Entries", "-",
            "Show Only Level Info", "Show Only Tags #network", "Show Only Category “websocket”",
            "Show Only Source “Sockets”", "-",
            "Hide Level Info", "Hide Tags #network", "Hide Category “websocket”", "Hide Source “Sockets”",
            "Search for “Socket connected”"
        ])
    }

    @Test func multipleRowsGetACountSuffixAndActiveFiltersAddItems() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleFacetValue("default", in: .attribute("category"))
        await harness.waitForFilter()

        let entries = makeEntries(harness.session, recordIndices: [1, 2], showDetails: {})
        let titles = Self.titles(entries)

        #expect(titles.contains("Copy Entry (2)"))
        #expect(titles.contains("Add Bookmark (2)"))
        #expect(titles.contains("Show in Full Log"))
        #expect(titles.contains("Clear Selected Entries (2)"))
        #expect(titles.suffix(2) == ["-", "Clear Filters"])
    }

    @Test func actionsCallTheSessionAndThePasteboard() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        var detailsShown = 0

        let entries = makeEntries(harness.session, recordIndices: [1]) { detailsShown += 1 }
        Self.run("Copy as JSON", in: entries)
        Self.run("Copy Message", in: entries)
        Self.run("Copy Entry", in: entries)
        Self.run("Show Details", in: entries)
        Self.run("Add Bookmark", in: entries)

        #expect(pasteboard.writtenTexts.first?.hasPrefix("{\n  \"number\" : 2,") == true)
        #expect(pasteboard.writtenTexts[1] == "Payment failed")
        #expect(pasteboard.writtenTexts.last?.hasPrefix("Payment failed ERR") == true)
        #expect(detailsShown == 1)
        #expect(harness.session.isBookmarked(harness.session.content.records[1]))
        Self.run("Copy Source “Store:20”", in: entries)
        #expect(pasteboard.writtenTexts.last == "Store:20")
        #expect(Self.titles(makeEntries(harness.session, recordIndices: [1], showDetails: {})).contains("Remove Bookmark"))
    }

    @Test func hideItemsExcludeTheValues() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.showOnly(["websocket"], in: .attribute("category"))

        let entries = makeEntries(harness.session, recordIndices: [1], showDetails: {})
        Self.run("Hide Level Error", in: entries)
        Self.run("Hide Category “default”", in: entries)
        Self.run("Hide Source “Store”", in: entries)
        Self.run("Hide Tags #network", in: makeEntries(harness.session, recordIndices: [0], showDetails: {}))
        Self.run("Hide Level Debug", in: makeEntries(harness.session, recordIndices: [2], showDetails: {}))

        let facets = harness.session.filterState.facets
        #expect(facets.levels == .except(["error", "debug"]))
        #expect(facets[.attribute("category")] == .except(["default"]))
        #expect(facets[.attribute("source")] == .except(["Store"]))
        #expect(facets[.attribute("tags")] == .except(["network"]))
    }

    @Test func searchForCutsLongMessagesAndPersistsTheScope() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let long = String(repeating: "a", count: 45)
        await harness.start(with: [LogFixtures.entry(long + " ⏎ second line", level: "INF")])
        harness.session.setSearchScope(SearchScope(ids: ["tags"]))

        let entries = makeEntries(harness.session, recordIndices: [0], showDetails: {})
        let title = "Search for “" + String(repeating: "a", count: 40) + "…”"
        #expect(Self.titles(entries).contains(title))

        Self.run(title, in: entries)

        #expect(harness.session.filterState.searchText == long)
        #expect(harness.session.filterState.searchScope == SearchScope(ids: ["tags", "message"]))
        #expect(settings.searchScope == SearchScope(ids: ["tags", "message"]))
    }

    @Test func timeRangeItemsNeedTimestamps() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample + ["Plain text without a header\n"])
        let first = try #require(harness.session.record(at: 0)?.timestamp)
        let third = try #require(harness.session.record(at: 2)?.timestamp)

        let single = Self.titles(makeEntries(harness.session, recordIndices: [1], showDetails: {}))
        #expect(single.contains("Show Only From This Entry"))
        #expect(single.contains("Show Only Between Selected Entries") == false)

        let plain = Self.titles(makeEntries(harness.session, recordIndices: [3], showDetails: {}))
        #expect(plain.contains("Show Only From This Entry") == false)

        let oneTimestamp = Self.titles(makeEntries(harness.session, recordIndices: [0, 3], showDetails: {}))
        #expect(oneTimestamp.contains("Show Only Between Selected Entries") == false)

        let two = makeEntries(harness.session, recordIndices: [2, 0, 3], showDetails: {})
        #expect(Self.titles(two).contains("Show Only Between Selected Entries"))

        Self.run("Show Only Between Selected Entries", in: two)
        #expect(harness.session.filterState.timeRange == first...third)

        Self.run("Show Only From This Entry", in: makeEntries(harness.session, recordIndices: [0], showDetails: {}))
        #expect(harness.session.filterState.timeRange == first...Double.greatestFiniteMagnitude)
    }

    @Test func clearItemsClearAroundTheClickedEntry() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        Self.run("Clear Entries Before This", in: makeEntries(harness.session, recordIndices: [1], showDetails: {}))
        Self.run("Clear Entries After This", in: makeEntries(harness.session, recordIndices: [1], showDetails: {}))

        #expect(harness.session.filterState.markIndex == 1)
        #expect(harness.session.filterState.clearedAfterRange == 2..<3)

        let entries = makeEntries(harness.session, recordIndices: [0, 2], showDetails: {})
        #expect(Self.titles(entries).contains("Restore All Entries"))
        Self.run("Clear Selected Entries (2)", in: entries)
        #expect(harness.session.clearedCounts.selected == 2)

        Self.run("Restore All Entries", in: makeEntries(harness.session, recordIndices: [1], showDetails: {}))
        #expect(harness.session.hasClearedEntries == false)
    }

    @Test func openInXcodeOpensTheSourceOfTheRecord() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let url = URL(fileURLWithPath: "/tmp/project/Store.swift")
        let profiles = await RegistryFixtures.loaded(settings: settings, profile: LogFixtures.profile)
        index.locations["Store"] = [url]

        Self.run("Open in Xcode", in: makeEntries(harness.session, recordIndices: [1], profiles: profiles, showDetails: {}))

        #expect(opener.opened.map(\.0) == [url])
        #expect(opener.opened.map(\.1) == [20])
    }

    @Test func openInXcodeNeedsASource() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: ["No source INF 2026-10-07 22:18:54.000\n"])

        let titles = Self.titles(makeEntries(harness.session, recordIndices: [0], showDetails: {}))

        #expect(titles.contains("Show Details"))
        #expect(titles.contains("Open in Xcode") == false)
    }

    @Test func noRecordGivesNoEntries() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        #expect(makeEntries(harness.session, recordIndices: [5], showDetails: {}).isEmpty)
    }

    private func makeEntries(
        _ session: LogSession,
        recordIndices: [Int],
        showDetails: @escaping @MainActor () -> Void
    ) -> [ContextMenuEntry] {
        makeEntries(session, recordIndices: recordIndices, profiles: RegistryFixtures.empty(settings: settings), showDetails: showDetails)
    }

    private func makeEntries(
        _ session: LogSession,
        recordIndices: [Int],
        profiles: ProfileRegistry,
        showDetails: @escaping @MainActor () -> Void
    ) -> [ContextMenuEntry] {
        RowContextMenuModel.entries(
            session: session,
            recordIndices: recordIndices,
            copyEntries: CopyEntries(pasteboard: pasteboard),
            openSource: OpenSource(index: index, opener: opener, dialogs: FakeFileDialogs(), profiles: profiles),
            settings: settings,
            showDetails: showDetails
        )
    }

    static func titles(_ entries: [ContextMenuEntry]) -> [String] {
        entries.map { entry in
            guard case .item(let item) = entry else { return "-" }
            return item.title
        }
    }

    static func run(_ title: String, in entries: [ContextMenuEntry]) {
        for entry in entries {
            guard case .item(let item) = entry, item.title == title else { continue }
            item.action()
            return
        }
        Issue.record("No menu item \(title)")
    }
}
