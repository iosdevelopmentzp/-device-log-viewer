import Foundation
import LogReaderCore
@testable import LogReaderKit

@MainActor
struct SessionHarness {

    let source: FakeLogSource
    let repository: FakeBookmarkRepository
    let observer: FakeLogRowsObserver
    let session: LogSession
    var fixtures = LogFixtures()

    init(bookmarks: Set<Int>, debounce: Duration) {
        self.init(bookmarks: bookmarks, debounce: debounce, profile: LogFixtures.profile)
    }

    init(bookmarks: Set<Int>, debounce: Duration, profile: LogProfile) {
        self.source = FakeLogSource(url: LogFixtures.url)
        self.repository = FakeBookmarkRepository(stored: [LogFixtures.url: bookmarks])
        self.observer = FakeLogRowsObserver()
        self.session = LogSession(
            url: LogFixtures.url,
            profile: profile,
            source: source,
            bookmarkRepository: repository,
            filterRunner: LogFilterRunner(debounce: debounce),
            searchScope: .message,
            isRegex: false
        )
    }

    mutating func start(with entries: [String]) async {
        session.rowsObserver = observer
        session.start()
        await send(entries)
    }

    mutating func send(_ entries: [String]) async {
        let expected = session.content.records.count + entries.count
        source.send(.batch(fixtures.batch(entries)))
        await Eventually.wait { session.content.records.count == expected }
    }

    func waitForFilter() async {
        await Eventually.wait { session.isFiltering == false }
    }
}
