import Foundation

public protocol BookmarkRepository: AnyObject {
    func bookmarks(for url: URL) -> Set<Int>
    func save(_ offsets: Set<Int>, for url: URL)
}
