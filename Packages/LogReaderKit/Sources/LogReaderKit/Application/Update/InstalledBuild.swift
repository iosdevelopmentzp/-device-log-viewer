import Foundation

public struct InstalledBuild: Sendable, Equatable, Decodable {
    public let commit: String
    public let branch: String
    public let source: String
    public let installedAt: Date

    public var shortCommit: String { String(commit.prefix(7)) }

    public init(commit: String, branch: String, source: String, installedAt: Date) {
        self.commit = commit
        self.branch = branch
        self.source = source
        self.installedAt = installedAt
    }
}
