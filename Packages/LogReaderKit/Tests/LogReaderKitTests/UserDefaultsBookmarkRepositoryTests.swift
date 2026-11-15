import Foundation
import Testing
@testable import LogReaderKit

struct UserDefaultsBookmarkRepositoryTests {

    @Test func savedBookmarksRoundTrip() {
        let store = InMemoryKeyValueStore()
        let repository = UserDefaultsBookmarkRepository(store: store)
        let url = URL(fileURLWithPath: "/tmp/logs/a.txt")

        repository.save([30, 10], for: url)

        #expect(repository.bookmarks(for: url) == [10, 30])
        #expect(repository.bookmarks(for: URL(fileURLWithPath: "/tmp/logs/b.txt")).isEmpty)
        #expect(store.dictionary(forKey: "bookmarks.byFilePath") as? [String: [Int]] == ["/tmp/logs/a.txt": [10, 30]])
    }

    @Test func pathsAreStandardized() {
        let repository = UserDefaultsBookmarkRepository(store: InMemoryKeyValueStore())

        repository.save([1], for: URL(fileURLWithPath: "/tmp/logs/../logs/a.txt"))

        #expect(repository.bookmarks(for: URL(fileURLWithPath: "/tmp/logs/a.txt")) == [1])
    }

    @Test func emptySetRemovesTheFile() {
        let store = InMemoryKeyValueStore()
        let repository = UserDefaultsBookmarkRepository(store: store)
        let url = URL(fileURLWithPath: "/tmp/logs/a.txt")
        repository.save([1], for: url)

        repository.save([], for: url)

        #expect(repository.bookmarks(for: url).isEmpty)
        #expect(store.dictionary(forKey: "bookmarks.byFilePath")?.isEmpty == true)
    }
}
