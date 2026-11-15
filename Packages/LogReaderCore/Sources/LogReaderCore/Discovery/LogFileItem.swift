import Foundation

public struct LogFileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let size: Int64
    public let createdAt: Date

    public var id: String { url.path }

    public init(url: URL, size: Int64, createdAt: Date) {
        self.url = url
        self.size = size
        self.createdAt = createdAt
    }
}
