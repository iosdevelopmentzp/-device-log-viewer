import Foundation
import LogReaderKit

final class FakeBookmarkRepository: BookmarkRepository {

    private(set) var stored: [URL: Set<Int>] = [:]
    private(set) var saveCount = 0

    init(stored: [URL: Set<Int>]) {
        self.stored = stored
    }

    func bookmarks(for url: URL) -> Set<Int> {
        stored[url] ?? []
    }

    func save(_ offsets: Set<Int>, for url: URL) {
        saveCount += 1
        stored[url] = offsets
    }
}
