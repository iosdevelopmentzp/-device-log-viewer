import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct MainViewModelTests {

    private let discovery = FakeLogDiscovery(devices: [])
    private let sourceFactory = FakeLogSourceFactory()
    private let pasteboard = FakePasteboard()
    private let dialogs = FakeFileDialogs()
    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let index = FakeSourceFileIndex()
    private let opener = FakeSourceOpener()
    private let attention = FakeAppAttention()
    private let writer = FakeFileWriter()
    private let revealer = FakeFileRevealer()
    private let workspace: Workspace
    private let profiles: ProfileRegistry

    init() async {
        profiles = await RegistryFixtures.loaded(settings: settings, profile: ProfileFixtures.textTrailing)
        workspace = Workspace(
            sidebar: SidebarStore(discovery: discovery, scanInterval: .milliseconds(5)),
            sessionFactory: DefaultLogSessionFactory(
                sourceFactory: sourceFactory,
                bookmarkRepository: FakeBookmarkRepository(stored: [:]),
                debounce: .milliseconds(1)
            ),
            settings: settings,
            profiles: profiles
        )
    }

    @Test func sessionViewModelsAreRebuiltWhenTheSessionChanges() {
        let model = makeModel()
        model.start()
        #expect(model.sessionViews == nil)
        #expect(model.hasSession == false)
        #expect(model.title == "LogReader")
        #expect(model.status == nil)

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        let first = model.sessionViews

        #expect(first?.session === workspace.session)
        #expect(workspace.session?.rowsObserver === first?.table)
        #expect(model.title == "log-1.txt")

        workspace.open(URL(fileURLWithPath: "/tmp/log-2.txt"))
        let second = model.sessionViews

        #expect(second?.session === workspace.session)
        #expect(second?.table !== first?.table)
        #expect(second?.search !== first?.search)
        #expect(second?.inspector !== first?.inspector)
        #expect(second?.filterMenu !== first?.filterMenu)
        #expect(workspace.session?.rowsObserver === second?.table)
        model.stop()
    }

    @Test func errorAlertsFollowTheOpenSession() async {
        let model = makeModel()
        model.start()
        #expect(attention.observer != nil)

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        let first = workspace.session
        #expect(first?.appendObserver is ErrorAlertController)

        workspace.open(URL(fileURLWithPath: "/tmp/log-2.txt"))
        guard let session = workspace.session else {
            Issue.record("No session")
            return
        }
        #expect(first?.appendObserver == nil)
        #expect(session.appendObserver is ErrorAlertController)

        var fixtures = LogFixtures()
        sourceFactory.sources[1].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 3 }
        sourceFactory.sources[1].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 6 }

        #expect(attention.attentionRequests == 1)
        #expect(attention.badges == ["1"])

        model.stop()
        #expect(attention.observer == nil)
        #expect(session.appendObserver == nil)
    }

    @Test func openFileUsesTheDialogAndAddsTheFileToTheList() {
        let model = makeModel()
        model.start()
        let url = URL(fileURLWithPath: "/tmp/chosen.txt")

        model.openFile()
        #expect(model.hasSession == false)

        dialogs.fileToChoose = url
        model.openFile()

        #expect(workspace.session?.url == url)
        #expect(workspace.sidebar.openedFiles == [url])
        model.stop()
    }

    @Test func droppedFilesOpenTheFirstOne() {
        let model = makeModel()
        model.start()
        let url = URL(fileURLWithPath: "/tmp/dropped.txt")

        #expect(model.openDropped([]) == false)
        #expect(model.openDropped([url, URL(fileURLWithPath: "/tmp/other.txt")]))
        #expect(workspace.session?.url == url)
        model.stop()
    }

    @Test func openExternalOpensTheFileAndAddsItToTheList() {
        let model = makeModel()
        model.start()
        let url = URL(fileURLWithPath: "/tmp/external.txt")

        model.openExternal(url)

        #expect(workspace.session?.url == url)
        #expect(workspace.sidebar.openedFiles == [url])
        model.stop()
    }

    @Test func openInNewWindowSetsARequestWithANewIDEachTime() {
        let model = makeModel()
        let url = URL(fileURLWithPath: "/tmp/log-1.txt")
        #expect(model.windowRequest == nil)

        model.openInNewWindow(nil)
        let first = model.windowRequest
        model.openInNewWindow(url)
        let second = model.windowRequest
        model.openInNewWindow(url)

        #expect(first?.url == nil)
        #expect(second?.url == url)
        #expect(model.windowRequest?.url == url)
        #expect(first?.id != second?.id)
        #expect(second?.id != model.windowRequest?.id)
        #expect(model.hasSession == false)
    }

    @Test func sidebarOpenInNewWindowSetsARequest() {
        let model = makeModel()
        let url = URL(fileURLWithPath: "/tmp/log-1.txt")

        model.sidebar.openInNewWindow(SidebarFileItem(url: url, title: "1", sizeText: "", matchText: "", isNewest: false, canDelete: true))

        #expect(model.windowRequest?.url == url)
        #expect(model.hasSession == false)
    }

    @Test func subtitleNamesTheDevice() async {
        let logsPath = "/tmp/device/app/Logs"
        discovery.setDevices([
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.app", logsPath: logsPath, files: ["log-1.txt"])])
        ])
        let model = makeModel()
        model.start()
        await Eventually.wait { workspace.sidebar.devices.isEmpty == false }

        workspace.open(URL(fileURLWithPath: logsPath + "/log-1.txt"))

        #expect(model.subtitle == "iPhone A · iOS 26.0")
        model.stop()
    }

    @Test func windowFlagsAndFocusRequests() {
        let model = makeModel()

        #expect(model.isInspectorPresented)
        model.toggleInspector()
        #expect(model.isInspectorPresented == false)
        model.requestInspectorSearchFocus()
        #expect(model.isInspectorPresented)
        #expect(model.inspectorSearchFocusRequest == 1)
        model.requestSearchFocus()
        #expect(model.searchFocusRequest == 1)
        model.toggleInspector()
        model.showInspector()
        #expect(model.isInspectorPresented)
        model.showGoToEntry()
        #expect(model.isGoToEntryPresented)
    }

    @Test func presetSheetsToggle() {
        let model = makeModel()
        model.start()

        model.showManagePresets()
        #expect(model.presets.isManagePresented)

        model.showSavePreset()
        #expect(model.presets.isNamePromptPresented == false)

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        workspace.session?.setBookmarksOnly(true)
        model.showSavePreset()
        #expect(model.presets.isNamePromptPresented)
        #expect(model.presets.draftName == "Bookmarks")
        model.stop()
    }

    @Test func commandsForwardToTheSession() async {
        let model = makeModel()
        model.start()
        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        guard let session = workspace.session else {
            Issue.record("No session")
            return
        }
        var fixtures = LogFixtures()
        sourceFactory.sources[0].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 3 }

        #expect(model.entryCount == 3)
        #expect(model.goToEntryPrompt == "Entry number (1–3)")
        #expect(model.status?.entriesText == "3 entries")
        #expect(model.followSymbolName == "arrow.down.to.line.circle.fill")
        #expect(model.canFindInEntry == false)
        #expect(model.canFindNext == false)
        #expect(model.hasBookmarks == false)

        model.goToEntry(number: 2)
        #expect(session.selectedRecords == [1])
        #expect(model.canFindInEntry)
        #expect(model.followSymbolName == "arrow.down.to.line.circle")

        model.toggleBookmark()
        #expect(session.bookmarks == [session.content.records[1].offset])
        #expect(model.hasBookmarks)

        model.copySelection()
        model.copyVisible()
        #expect(pasteboard.writtenTexts.count == 2)

        model.toggleBookmarksOnly()
        #expect(session.filterState.bookmarksOnly)
        model.clearFilters()
        #expect(session.filterState.bookmarksOnly == false)

        model.clearBookmarks()
        #expect(session.bookmarks.isEmpty)
        #expect(model.hasBookmarks == false)

        model.jumpToEnd()
        #expect(session.isFollowing)
        model.stop()
    }

    @Test func clearCommandsForwardToTheSession() async {
        let model = makeModel()
        model.start()
        #expect(model.hasClearedEntries == false)
        #expect(model.canClearAroundSelection == false)
        #expect(model.canClearSelection == false)
        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        guard let session = workspace.session else {
            Issue.record("No session")
            return
        }
        var fixtures = LogFixtures()
        sourceFactory.sources[0].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 3 }

        model.clearAllEntries()
        #expect(model.hasClearedEntries)
        #expect(session.filterState.markIndex == 3)
        model.restoreAllEntries()
        #expect(model.hasClearedEntries == false)

        session.selectedRecords = [1]
        #expect(model.canClearAroundSelection)
        #expect(model.canClearSelection)
        model.clearEntriesBeforeSelection()
        model.clearEntriesAfterSelection()
        #expect(session.filterState.markIndex == 1)
        #expect(session.filterState.clearedAfterRange == 2..<3)

        session.selectedRecords = [0, 1]
        #expect(model.canClearAroundSelection == false)
        model.clearSelectedEntries()
        #expect(session.clearedCounts.selected == 2)
        #expect(model.canClearSelection == false)
        model.stop()
    }

    @Test func showTimeRangeBuildsAFreshViewModelAndPresentsTheSheet() {
        let model = makeModel()
        model.start()

        model.showTimeRange()
        #expect(model.timeRange == nil)
        #expect(model.isTimeRangePresented == false)

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        model.showTimeRange()
        let first = model.timeRange

        #expect(first != nil)
        #expect(model.isTimeRangePresented)

        model.isTimeRangePresented = false
        model.showTimeRange()

        #expect(model.timeRange !== first)
        #expect(model.isTimeRangePresented)

        model.stop()
    }

    @Test func openSourceOfSelectionUsesThePrimarySelection() async {
        let model = makeModel()
        model.start()
        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        guard let session = workspace.session else {
            Issue.record("No session")
            return
        }
        var fixtures = LogFixtures()
        sourceFactory.sources[0].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 3 }
        let url = URL(fileURLWithPath: "/tmp/project/Sockets.swift")
        index.locations["Sockets"] = [url]

        #expect(model.canOpenSource == false)
        model.openSourceOfSelection()
        #expect(opener.opened.isEmpty)

        session.selectedRecords = [0]
        #expect(model.canOpenSource)
        #expect(model.openSourceTitle == "Open Source in Xcode")
        model.openSourceOfSelection()
        #expect(dialogs.presentedErrors.isEmpty)
        #expect(opener.opened.map(\.0) == [url])
        #expect(opener.opened.map(\.1) == [10])
        #expect(opener.editors == [ProfileFixtures.textTrailing.source])
        model.stop()
    }

    @Test func exportVisibleWritesTheFileAndShowsProgress() async throws {
        let model = makeModel()
        model.start()
        #expect(model.canExport == false)

        workspace.open(URL(fileURLWithPath: "/tmp/log-1.txt"))
        let session = try #require(workspace.session)
        #expect(model.canExport == false)
        var fixtures = LogFixtures()
        sourceFactory.sources[0].send(.batch(fixtures.batch(LogFixtures.sample)))
        await Eventually.wait { session.content.records.count == 3 }
        #expect(model.canExport)

        let destination = URL(fileURLWithPath: "/tmp/out/export.json")
        dialogs.saveLocation = destination
        let gate = DispatchSemaphore(value: 0)
        writer.hold(until: gate)
        let export = Task { await model.exportVisible(format: .json) }
        await Eventually.wait { model.isExporting }

        #expect(model.status?.isExporting == true)
        #expect(model.canExport == false)

        gate.signal()
        await export.value

        #expect(model.isExporting == false)
        #expect(model.status?.isExporting == false)
        #expect(dialogs.suggestedNames == ["log-1-filtered.json"])
        #expect(writer.writes.map(\.url) == [destination])
        #expect(revealer.revealedURLs == [destination])
        model.stop()
    }

    private func makeModel() -> MainViewModel {
        let copyEntries = CopyEntries(pasteboard: pasteboard)
        let fileActions = FileActions(
            pasteboard: pasteboard,
            revealer: FakeFileRevealer(),
            dialogs: dialogs,
            copier: FakeFileCopier()
        )
        return MainViewModel(
            workspace: workspace,
            sidebar: SidebarViewModel(
                workspace: workspace,
                fileActions: fileActions,
                deleteLogFiles: DeleteLogFiles(trasher: FakeFileTrasher(), dialogs: dialogs),
                settings: settings,
                contentSearch: SidebarContentSearch(
                    searcher: FakeFileContentSearcher(),
                    debounce: .milliseconds(1),
                    sizeLimit: 1_000
                )
            ),
            settings: settings,
            fileDialogs: dialogs,
            copyEntries: copyEntries,
            openSource: OpenSource(index: index, opener: opener, dialogs: dialogs, profiles: profiles),
            exportEntries: ExportEntries(dialogs: dialogs, writer: writer, revealer: revealer),
            attention: attention,
            filterRecordDelay: .milliseconds(10)
        )
    }
}
