import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct FilterHistoryRecorderTests {

    private let settings = AppSettings(store: InMemoryKeyValueStore())
    private let harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))

    @Test func recordsTheFacetStateAfterTheDelay() async {
        let recorder = makeRecorder()
        recorder.start()

        harness.session.toggleFacetValue("error", in: .level)
        await settle()
        harness.session.toggleFacetValue("fault", in: .level)
        await Eventually.wait { settings.filterHistory.entries.isEmpty == false }
        await settle()

        #expect(settings.filterHistory.entries.count == 1)
        #expect(settings.filterHistory.entries.first?.facets.levels == .only(["error", "fault"]))
        #expect(settings.filterHistory.entries.first?.bookmarksOnly == false)
        recorder.stop()
    }

    @Test func recordsBookmarksOnly() async {
        let recorder = makeRecorder()
        recorder.start()

        harness.session.setBookmarksOnly(true)
        await Eventually.wait { settings.filterHistory.entries.isEmpty == false }

        #expect(settings.filterHistory.entries.first?.facets == .all)
        #expect(settings.filterHistory.entries.first?.bookmarksOnly == true)
        recorder.stop()
    }

    @Test func passThroughStateAndSearchTextAreNotRecorded() async {
        let recorder = makeRecorder()
        recorder.start()

        harness.session.toggleFacetValue("error", in: .level)
        await settle()
        harness.session.showAll(in: .level)
        harness.session.setSearchText("payment")
        await waitPastDelay()

        #expect(settings.filterHistory == .empty)
        recorder.stop()
    }

    @Test func stopCancelsThePendingRecord() async {
        let recorder = makeRecorder()
        recorder.start()

        harness.session.toggleFacetValue("error", in: .level)
        await settle()
        recorder.stop()
        harness.session.toggleFacetValue("warning", in: .level)
        await waitPastDelay()

        #expect(settings.filterHistory == .empty)
    }
}

// MARK: - Private

private extension FilterHistoryRecorderTests {

    static let delay: Duration = .milliseconds(150)

    func makeRecorder() -> FilterHistoryRecorder {
        FilterHistoryRecorder(session: harness.session, settings: settings, delay: Self.delay)
    }

    func settle() async {
        try? await Task.sleep(for: .milliseconds(30))
    }

    func waitPastDelay() async {
        try? await Task.sleep(for: Self.delay + .milliseconds(100))
    }
}
