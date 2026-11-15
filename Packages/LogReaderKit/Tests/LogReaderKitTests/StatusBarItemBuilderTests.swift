import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct StatusBarItemBuilderTests {

    @Test func loadingSessionShowsZeroEntries() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        let item = StatusBarItemBuilder.item(for: harness.session, isExporting: false)

        #expect(item.kind == .loading)
        #expect(item.entriesText == "0 entries")
        #expect(item.sizeText == FileSizeText.file(0))
        #expect(item.isFollowing)
        #expect(item.jumpTitle == "Jump to End")
        #expect(item.isExporting == false)
    }

    @Test func exportingFlagIsPassedThrough() {
        let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: true).isExporting)
    }

    @Test func liveSessionShowsCountsSizeAndMatches() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: false).entriesText == "3 entries")
        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: false).kind == .live)
        #expect(
            StatusBarItemBuilder.item(for: harness.session, isExporting: false).sizeText
                == FileSizeText.file(Int64(harness.session.content.totalBytes))
        )

        harness.session.setSearchText("payment")
        await harness.waitForFilter()
        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: false).entriesText == "1 of 3 entries")

        harness.session.setSearchMode(.find)
        await harness.waitForFilter()
        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: false).entriesText == "3 entries · 1 matches")
    }

    @Test func detachedSessionCountsNewEntries() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.isFollowing = false

        await harness.send([LogFixtures.entry("New", level: "INF"), LogFixtures.entry("Newer", level: "INF")])

        let item = StatusBarItemBuilder.item(for: harness.session, isExporting: false)
        #expect(item.isFollowing == false)
        #expect(item.jumpTitle == "2 new")
    }

    @Test func missingFileGivesMissingKind() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)

        harness.source.send(.missing)
        await Eventually.wait { harness.session.status == .missing }

        #expect(StatusBarItemBuilder.item(for: harness.session, isExporting: false).kind == .missing)
    }
}
