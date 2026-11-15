import Foundation

public struct EntryTextLink: Sendable, Equatable {
    public let range: NSRange
    public let url: URL

    public init(range: NSRange, url: URL) {
        self.range = range
        self.url = url
    }
}
