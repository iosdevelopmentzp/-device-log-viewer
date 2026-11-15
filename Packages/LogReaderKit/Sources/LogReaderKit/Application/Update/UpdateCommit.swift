import Foundation

public struct UpdateCommit: Sendable, Equatable, Identifiable {
    public let shortHash: String
    public let subject: String

    public var id: String { shortHash }

    public init(shortHash: String, subject: String) {
        self.shortHash = shortHash
        self.subject = subject
    }
}
