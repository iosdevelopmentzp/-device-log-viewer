import Foundation

public struct WindowRequest: Equatable, Sendable {
    public let id: Int
    public let url: URL?

    public init(id: Int, url: URL?) {
        self.id = id
        self.url = url
    }
}
