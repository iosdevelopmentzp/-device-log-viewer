import Foundation

public struct SearchableFile: Sendable, Equatable {
    public let url: URL
    public let size: Int64

    public init(url: URL, size: Int64) {
        self.url = url
        self.size = size
    }
}
