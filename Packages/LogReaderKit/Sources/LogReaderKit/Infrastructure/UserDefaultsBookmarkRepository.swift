import Foundation

public final class UserDefaultsBookmarkRepository {

    private let store: any KeyValueStore

    private static let key = "bookmarks.byFilePath"

    public init(store: any KeyValueStore) {
        self.store = store
    }
}

// MARK: - BookmarkRepository

extension UserDefaultsBookmarkRepository: BookmarkRepository {

    public func bookmarks(for url: URL) -> Set<Int> {
        Set(storedBookmarks()[url.standardizedFileURL.path] ?? [])
    }

    public func save(_ offsets: Set<Int>, for url: URL) {
        var all = storedBookmarks()
        let path = url.standardizedFileURL.path
        if offsets.isEmpty {
            all.removeValue(forKey: path)
        } else {
            all[path] = offsets.sorted()
        }
        store.set(all, forKey: Self.key)
    }
}

// MARK: - Private

private extension UserDefaultsBookmarkRepository {

    func storedBookmarks() -> [String: [Int]] {
        store.dictionary(forKey: Self.key) as? [String: [Int]] ?? [:]
    }
}
