import Foundation
import Testing
@testable import LogReaderKit

@MainActor
struct CopyEntriesTests {

    private static let paymentText = "Payment failed ERR [default] [Store:20] 2026-10-07 22:18:55.000\n  reason: timeout"

    @Test func copiesRecordTextJoinedByNewline() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let pasteboard = FakePasteboard()
        let copyEntries = CopyEntries(pasteboard: pasteboard)

        copyEntries.copy(recordIndices: [0, 2, 9], from: harness.session)

        #expect(pasteboard.writtenTexts == [
            "Socket connected #network INF [websocket] [Sockets:10] 2026-10-07 22:18:54.000\n"
                + "Debug noise DBG [default] [Misc:30] 2026-10-07 22:18:56.000"
        ])
    }

    @Test func copySelectionUsesSelectedRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.selectedRecords = [1]
        let pasteboard = FakePasteboard()

        CopyEntries(pasteboard: pasteboard).copySelection(of: harness.session)

        #expect(pasteboard.writtenTexts == [Self.paymentText])
    }

    @Test func copyVisibleUsesVisibleRecords() async {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        harness.session.toggleFacetValue("error", in: .level)
        await harness.waitForFilter()
        let pasteboard = FakePasteboard()

        CopyEntries(pasteboard: pasteboard).copyVisible(of: harness.session)

        #expect(pasteboard.writtenTexts == [Self.paymentText])
    }

    @Test func copyJSONWritesTheEncodedEntry() async throws {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: LogFixtures.sample)
        let pasteboard = FakePasteboard()
        let copyEntries = CopyEntries(pasteboard: pasteboard)
        let record = try #require(harness.session.record(at: 1))

        copyEntries.copyJSON(recordIndex: 1, from: harness.session)
        copyEntries.copyJSON(recordIndex: 9, from: harness.session)

        #expect(pasteboard.writtenTexts == [
            EntryJSONEncoder.json(number: 2, record: record, text: harness.session.text(of: record), profile: LogFixtures.profile)
        ])
    }

    @Test func copyTextWritesText() {
        let pasteboard = FakePasteboard()

        CopyEntries(pasteboard: pasteboard).copy(text: "hello")

        #expect(pasteboard.writtenTexts == ["hello"])
    }
}
