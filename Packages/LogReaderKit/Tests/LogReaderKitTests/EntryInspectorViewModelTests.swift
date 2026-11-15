import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct EntryInspectorViewModelTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let pasteboard = FakePasteboard()
    private let index = FakeSourceFileIndex()
    private let opener = FakeSourceOpener()

    @Test func withoutSelectionNothingIsLoaded() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = makeModel(harness.session)

        await model.load()

        #expect(model.hasSelection == false)
        #expect(model.isLoading == false)
        #expect(model.header == nil)
        #expect(model.layout == nil)
        #expect(model.loadKey == nil)
    }

    @Test func loadBuildsTheHeaderAndTheLayout() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        settings.timeZoneMode = .utc
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)

        #expect(model.isLoading)
        await model.load()

        let record = harness.session.content.records[1]
        #expect(model.isLoading == false)
        #expect(model.layout?.text.string == "Payment failed\n\nreason\ntimeout")
        #expect(model.header == EntryHeaderItem(
            number: 2,
            numberText: "#2",
            levelStyle: .red,
            levelTitle: "Error",
            isBookmarked: false,
            metadata: [
                EntryHeaderItem.MetadataRow(title: "Time", value: TimeTextFormatter(timeZoneMode: .utc).fullDate(record.timestamp), isSource: false),
                EntryHeaderItem.MetadataRow(title: "Category", value: "default", isSource: false),
                EntryHeaderItem.MetadataRow(title: "Source", value: "Store:20", isSource: true),
                EntryHeaderItem.MetadataRow(title: "Size", value: FileSizeText.memory(Int64(record.length)), isSource: false)
            ],
            sizeText: FileSizeText.memory(Int64(record.length)),
            hasSource: true,
            openSourceTitle: "Open in Xcode"
        ))
    }

    @Test func headerListsTagsWithTheirPrefix() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [0]
        let model = makeModel(harness.session)

        #expect(model.header?.levelStyle == .blue)
        #expect(model.header?.levelTitle == "Info")
        #expect(model.header?.metadata.map(\.title) == ["Time", "Tags", "Category", "Source", "Size"])
        #expect(model.header?.metadata[1].value == "#network")
    }

    @Test func matchNavigationWrapsAndMovesTheFocusRange() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)

        model.entrySearchText = "t"
        await model.load()

        let matches = model.layout?.localMatches ?? []
        #expect(matches.count == 3)
        #expect(model.showsMatchControls)
        #expect(model.canNavigateMatches)
        #expect(model.matchCountText == "1/3")
        #expect(model.focusRange == matches[0])

        model.nextMatch()
        model.nextMatch()
        #expect(model.matchCountText == "3/3")
        model.nextMatch()
        #expect(model.focusRange == matches[0])
        model.previousMatch()
        #expect(model.focusRange == matches[2])

        model.entrySearchText = "nothing"
        await model.load()
        #expect(model.matchCountText == "No matches")
        #expect(model.focusRange == nil)
        #expect(model.canNavigateMatches == false)

        model.clearEntrySearch()
        #expect(model.showsMatchControls == false)
    }

    @Test func loadKeyChangesWithSearchAndFontSize() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)
        let first = model.loadKey

        model.entrySearchText = "a"
        let second = model.loadKey
        settings.fontSize = 20
        let third = model.loadKey
        harness.session.selectedRecords = [0]

        #expect(first != nil)
        #expect(first != second)
        #expect(second != third)
        #expect(model.loadKey != third)
    }

    @Test func globalSearchIsHighlightedBeforeLocalSearch() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.setSearchText("timeout")
        await harness.waitForFilter()
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)
        model.entrySearchText = "out"

        await model.load()

        #expect(model.layout?.text.spans.suffix(2).map(\.style) == [.globalMatch, .localMatch])
    }

    @Test func copyActionsWriteToThePasteboard() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)
        await model.load()

        model.copyEntry()
        model.copyMessage()
        let items = model.copyItems
        items.last?.action()
        model.copyJSON()

        #expect(items.map(\.title) == ["Copy Entry", "Copy Message", "Copy as JSON", "Copy “reason”"])
        #expect(pasteboard.writtenTexts[0] == harness.session.text(of: harness.session.content.records[1]))
        #expect(pasteboard.writtenTexts[1] == "Payment failed")
        #expect(pasteboard.writtenTexts[2] == "timeout")
        #expect(pasteboard.writtenTexts[3].hasPrefix("{\n  \"number\" : 2,"))
    }

    @Test func selectingAnotherRecordShowsLoadingUntilLoaded() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)
        await model.load()

        harness.session.selectedRecords = [0]
        #expect(model.isLoading)
        #expect(model.copyItems.isEmpty)

        await model.load()
        #expect(model.isLoading == false)
        #expect(model.layout?.text.string.hasPrefix("Socket connected") == true)
    }

    @Test func openSourceOpensTheSelectedRecord() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let registry = await RegistryFixtures.loaded(settings: settings, profile: LogFixtures.profile)
        let model = makeModel(harness.session, profiles: registry)
        let url = URL(fileURLWithPath: "/tmp/project/Store.swift")
        index.locations["Store"] = [url]

        #expect(model.canOpenSource == false)
        model.openSource()
        #expect(opener.opened.isEmpty)

        harness.session.selectedRecords = [1]
        #expect(model.canOpenSource)
        #expect(model.header?.hasSource == true)
        model.openSource()

        #expect(opener.opened.map(\.0) == [url])
        #expect(opener.opened.map(\.1) == [20])
        #expect(index.roots == [RegistryFixtures.projectRoot])
        #expect(index.preferredExtensions == ["swift"])
    }

    @Test func recordWithoutSourceCannotOpenIt() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: ["No source INF 2026-10-07 22:18:54.000\n"])
        harness.session.selectedRecords = [0]
        let model = makeModel(harness.session)

        #expect(model.canOpenSource == false)
        #expect(model.header?.hasSource == false)
    }

    @Test func loadBuildsJSONFieldsWithDefaultExpansion() async {
        let model = await loadedJSONModel()

        #expect(model.jsonFields.map(\.key) == ["payload"])
        #expect(model.jsonFields.first?.tree.valueText == "{3}")
        #expect(model.expandedNodeIDs == ["0:payload/$", "0:payload/$.items", "0:payload/$.user"])
        #expect(model.isExpanded("0:payload/$.user"))
    }

    @Test func visibleRowsFollowTheExpansion() async throws {
        let model = await loadedJSONModel()
        let field = try #require(model.jsonFields.first)

        let rows = model.visibleRows(of: field)
        #expect(rows.map(\.key) == ["$", "items", "[0]", "[1]", "ok", "user", "id", "name"])
        #expect(rows.map(\.depth) == [0, 1, 2, 2, 1, 1, 2, 2])
        #expect(rows.first?.valueStyle == .preview)
        #expect(rows.last?.valueStyle == .fieldValue)
        #expect(rows.last?.valueText == "\"Ann\"")

        model.toggleNode(id: "0:payload/$.items")
        let collapsed = model.visibleRows(of: field)
        #expect(collapsed.map(\.key) == ["$", "items", "ok", "user", "id", "name"])
        #expect(collapsed[1].isExpanded == false)

        model.toggleNode(id: "0:payload/$.ok")
        #expect(model.isExpanded("0:payload/$.ok") == false)
        model.toggleNode(id: "0:payload/$.items")
        #expect(model.visibleRows(of: field).count == 8)
    }

    @Test func jsonCopyActionsWriteToThePasteboard() async {
        let model = await loadedJSONModel()

        model.copyValue(nodeID: "0:payload/$.user.name")
        model.copyValue(nodeID: "0:payload/$.user")
        model.copyKeyPath(nodeID: "0:payload/$.items[1]")
        model.copySubtree(nodeID: "0:payload/$.items")
        model.copyValue(nodeID: "missing")

        #expect(pasteboard.writtenTexts == [
            "Ann",
            "{\n  \"id\" : 7,\n  \"name\" : \"Ann\"\n}",
            "$.items[1]",
            "[\n  1,\n  2\n]"
        ])
    }

    @Test func treeSectionIsHiddenWhileSearchingInTheEntry() async {
        let model = await loadedJSONModel()

        #expect(model.showsTreeSection)
        model.entrySearchText = "Ann"
        #expect(model.showsTreeSection == false)
    }

    @Test func treeModeIsStoredInTheSettings() async {
        let model = await loadedJSONModel()

        #expect(model.showsJSONTree)
        model.showsJSONTree = false
        #expect(settings.inspectorShowsJSONTree == false)
    }

    @Test func entryWithoutJSONHasNoJSONFields() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)

        await model.load()

        #expect(model.jsonFields.isEmpty)
        #expect(model.expandedNodeIDs.isEmpty)
    }

    private func loadedJSONModel() async -> EntryInspectorViewModel {
        let entry = "Request sent INF [default] [Net:5] 2026-10-07 22:18:57.000\n"
            + "  payload: {\"user\":{\"id\":7,\"name\":\"Ann\"},\"items\":[1,2],\"ok\":true}\n"
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: [entry])
        harness.session.selectedRecords = [0]
        let model = makeModel(harness.session)
        await model.load()
        return model
    }

    @Test func highlightWordSetsTheEntrySearchAndFindsLocalMatches() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let model = makeModel(harness.session)
        await model.load()
        model.entrySearchText = "t"
        await model.load()
        model.nextMatch()

        model.highlight(word: "timeout")
        await model.load()

        #expect(model.entrySearchText == "timeout")
        #expect(model.layout?.localMatches == [NSRange(location: 23, length: 7)])
        #expect(model.matchCountText == "1/1")
    }

    @Test func searchInLogSetsFindModeAndTheSearchText() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let model = makeModel(harness.session)

        model.searchInLog(text: "timeout")

        #expect(harness.session.filterState.searchMode == .find)
        #expect(harness.session.filterState.searchText == "timeout")
    }

    @Test func searchInLogTitleShortensLongText() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let model = makeModel(harness.session)

        #expect(model.searchInLogTitle(for: "timeout") == "Search for “timeout” in Log")
        #expect(model.searchInLogTitle(for: String(repeating: "a", count: 45)) == "Search for “\(String(repeating: "a", count: 40))…” in Log")
    }

    private func makeModel(_ session: LogSession) -> EntryInspectorViewModel {
        makeModel(session, profiles: RegistryFixtures.empty(settings: settings))
    }

    private func makeModel(_ session: LogSession, profiles: ProfileRegistry) -> EntryInspectorViewModel {
        EntryInspectorViewModel(
            session: session,
            settings: settings,
            copyEntries: CopyEntries(pasteboard: pasteboard),
            openSource: OpenSource(index: index, opener: opener, dialogs: FakeFileDialogs(), profiles: profiles)
        )
    }
}
