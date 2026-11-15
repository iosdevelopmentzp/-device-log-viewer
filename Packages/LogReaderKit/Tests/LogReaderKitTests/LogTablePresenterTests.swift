import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct LogTablePresenterTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let pasteboard = FakePasteboard()
    private let receiver = FakeLogTableUpdateReceiver()

    @Test func rowItemHasTheFormattedStringsAndSpans() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        settings.timeZoneMode = .utc
        let presenter = makePresenter(harness.session)
        presenter.start()
        let formatter = TimeTextFormatter(timeZoneMode: .utc)
        let record = harness.session.content.records[1]

        let row = presenter.row(at: 1)

        #expect(presenter.rowCount == 3)
        #expect(row?.number == 2)
        #expect(row?.numberText == "2")
        #expect(row?.time == formatter.time(record.timestamp))
        #expect(row?.fullDate == formatter.fullDate(record.timestamp))
        #expect(row?.delta == "+1.00s")
        #expect(row?.levelStyle == .red)
        #expect(row?.levelCode == "ERR")
        #expect(row?.highlightsRow == true)
        #expect(row?.attributes == ["", "default", "Store:20"])
        #expect(row?.attribute(at: 1) == "default")
        #expect(row?.attribute(at: 2) == "Store:20")
        #expect(row?.attribute(at: 3) == "")
        #expect(row?.message.string == "Payment failed   reason: timeout")
        #expect(row?.message.spans.map(\.style) == [.message(.red), .preview])
        #expect(row?.isBookmarked == false)
        #expect(row?.isFindMatch == false)
        #expect(presenter.row(at: 0)?.attribute(at: 0) == "#network")
        #expect(presenter.row(at: 0)?.levelStyle == .blue)
        #expect(presenter.row(at: 0)?.highlightsRow == false)
        #expect(presenter.row(at: 0)?.message.spans.map(\.style) == [.message(nil)])
        #expect(presenter.row(at: 0)?.delta == "")
        #expect(presenter.row(at: 3) == nil)
    }

    @Test func eventsReachTheReceiverAndReloadUpdatesTheHighlight() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)
        presenter.receiver = receiver
        presenter.start()

        harness.session.setSearchMode(.find)
        harness.session.setSearchText("payment")
        await harness.waitForFilter()

        #expect(receiver.events.contains(.reload))
        #expect(presenter.row(at: 1)?.message.spans.map(\.style) == [.message(.red), .preview, .globalMatch])
        #expect(presenter.row(at: 1)?.isFindMatch == true)

        receiver.removeAll()
        await harness.send([LogFixtures.entry("More", level: "INF")])
        #expect(receiver.events == [.inserted(3..<4)])
    }

    @Test func selectEventUpdatesTheSessionSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)
        presenter.receiver = receiver
        presenter.start()

        harness.session.goToEntry(number: 2)

        #expect(receiver.events == [.select(row: 1)])
        #expect(harness.session.selectedRecords == [1])
        #expect(presenter.selectedRows == [1])
        #expect(presenter.isFollowing == false)
    }

    @Test func selectionFollowingAndCopy() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)

        presenter.selectionDidChange(rows: [0, 2])
        presenter.setFollowing(false)
        presenter.copySelection()

        #expect(harness.session.selectedRecords == [0, 2])
        #expect(harness.session.isFollowing == false)
        #expect(pasteboard.writtenTexts.count == 1)
        #expect(pasteboard.writtenTexts[0].hasPrefix("Socket connected"))
        #expect(pasteboard.writtenTexts[0].contains("Debug noise"))
    }

    @Test func expandedMessageAndLineCount() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)
        presenter.start()

        let message = presenter.expandedMessage(at: 1)

        #expect(message?.string == "Payment failed\n  reason: timeout")
        #expect(message?.spans.map(\.style) == [.message(.red), .detail])
        #expect(presenter.lineCount(row: 1, columns: 200, maxLines: 400) == 2)
        #expect(presenter.lineCount(row: 1, columns: 10, maxLines: 3) == 3)
        #expect(presenter.lineCount(row: 9, columns: 10, maxLines: 3) == 1)
    }

    @Test func expandedMessageIsCut() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let body = String(repeating: "x", count: 50_000)
        await harness.start(with: ["Big INF [default] [Misc:1] 2026-10-07 22:18:54.000\n  data: \(body)\n"])
        let presenter = makePresenter(harness.session)

        #expect(presenter.expandedMessage(at: 0)?.string.count == 40_000)
    }

    @Test func headerTitlesAndToolTips() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)

        #expect(presenter.headerTitle(for: .attribute("source")) == "Source ▾")
        #expect(presenter.headerToolTip(for: .attribute("source")) == "Click to filter by source")

        harness.session.toggleFacetValue("error", in: .level)

        #expect(presenter.isFacetActive(.level))
        #expect(presenter.headerTitle(for: .level) == "Level ◉")
        #expect(presenter.headerToolTip(for: .level) == "Showing only 1 value. Click to change.")

        harness.session.hideOnly(["default", "websocket"], in: .attribute("category"))

        #expect(presenter.headerTitle(for: .attribute("category")) == "Category ⊘")
        #expect(presenter.headerToolTip(for: .attribute("category")) == "Hiding 2 values. Click to change.")
        #expect(presenter.facetFilterViewModel(for: .attribute("tags")).column == .attribute("tags"))
    }

    @Test func columnsFollowTheProfile() async {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let presenter = makePresenter(harness.session)

        #expect(presenter.columns.map(\.column) == LogTableColumn.all(in: LogFixtures.profile))
        #expect(presenter.columns.map(\.title) == ["#", "Time", "Δ", "Level", "Tags", "Category", "Source", "Message"])
    }

    @Test func contextMenuUsesTheRecordsOfTheRows() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let presenter = makePresenter(harness.session)

        let entries = presenter.contextMenu(forRows: [0, 1], showDetails: {})

        #expect(RowContextMenuModelTests.titles(entries).first == "Copy Entry (2)")
        #expect(RowContextMenuModelTests.titles(entries).contains("Copy Source “Store:20”"))
    }

    @Test func stopUnregistersThePresenter() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        let presenter = makePresenter(harness.session)

        presenter.start()
        #expect(harness.session.rowsObserver === presenter)

        presenter.stop()
        #expect(harness.session.rowsObserver == nil)
    }

    @Test func collapsingMapsRowsToGroups() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: repeated)
        let presenter = makePresenter(harness.session)
        presenter.receiver = receiver
        presenter.start()

        presenter.setCollapsesRepeats(true)

        #expect(receiver.events == [.reload])
        #expect(presenter.collapsesRepeats)
        #expect(presenter.rowCount == 2)
        #expect(presenter.row(at: 0)?.repeatCount == 3)
        #expect(presenter.row(at: 0)?.repeatCountText == "×3")
        #expect(presenter.row(at: 0)?.isGroupExpanded == false)
        #expect(presenter.row(at: 1)?.repeatCount == nil)
        #expect(presenter.row(at: 1)?.repeatCountText == "")
        #expect(presenter.row(at: 1)?.message.string == "Other")
        #expect(presenter.recordIndex(atRow: 0) == 0)
        #expect(presenter.recordIndex(atRow: 1) == 3)
        #expect(presenter.lineCount(row: 1, columns: 200, maxLines: 10) == 1)
        #expect(presenter.expandedMessage(at: 1)?.string == "Other")

        presenter.setCollapsesRepeats(false)

        #expect(presenter.rowCount == 4)
        #expect(presenter.row(at: 0)?.repeatCount == nil)
    }

    @Test func collapsingMapsTheSelection() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: repeated)
        let presenter = makePresenter(harness.session)
        presenter.start()
        presenter.setCollapsesRepeats(true)

        harness.session.selectedRecords = [1, 3]
        #expect(presenter.selectedRows == [0, 1])

        presenter.selectionDidChange(rows: [0, 1])
        #expect(harness.session.selectedRecords == [0, 3])

        presenter.toggleGroup(atRow: 0)
        harness.session.selectedRecords = [2]
        #expect(presenter.selectedRows == [2])
        #expect(presenter.row(at: 2)?.isGroupMember == true)
        #expect(presenter.row(at: 0)?.isGroupExpanded == true)
    }

    @Test func collapsingTranslatesInsertedRows() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: repeated)
        let presenter = makePresenter(harness.session)
        presenter.receiver = receiver
        presenter.start()
        presenter.setCollapsesRepeats(true)
        receiver.removeAll()

        await harness.send([LogFixtures.entry("Other", level: "DBG")])

        #expect(receiver.events == [.refreshRows])
        #expect(presenter.row(at: 1)?.repeatCount == 2)

        receiver.removeAll()
        await harness.send([LogFixtures.entry("New", level: "INF"), LogFixtures.entry("New", level: "INF")])

        #expect(receiver.events == [.inserted(2..<3)])
        #expect(presenter.row(at: 2)?.repeatCount == 2)
    }

    @Test func collapsingSelectExpandsTheGroup() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: repeated)
        let presenter = makePresenter(harness.session)
        presenter.receiver = receiver
        presenter.start()
        presenter.setCollapsesRepeats(true)
        receiver.removeAll()

        harness.session.goToEntry(number: 3)

        #expect(receiver.events == [.reload, .select(row: 2)])
        #expect(harness.session.selectedRecords == [2])
        #expect(presenter.row(at: 0)?.isGroupExpanded == true)
        #expect(presenter.recordIndex(atRow: 2) == 2)

        receiver.removeAll()
        harness.session.goToEntry(number: 4)

        #expect(receiver.events == [.select(row: 3)])
    }

    private var repeated: [String] {
        [
            LogFixtures.entry("Ping", level: "INF"),
            LogFixtures.entry("Ping", level: "INF"),
            LogFixtures.entry("Ping", level: "INF"),
            LogFixtures.entry("Other", level: "DBG")
        ]
    }

    private func makePresenter(_ session: LogSession) -> LogTablePresenter {
        LogTablePresenter(
            session: session,
            settings: settings,
            copyEntries: CopyEntries(pasteboard: pasteboard),
            openSource: OpenSource(
                index: FakeSourceFileIndex(),
                opener: FakeSourceOpener(),
                dialogs: FakeFileDialogs(),
                profiles: RegistryFixtures.empty(settings: settings)
            )
        )
    }
}
