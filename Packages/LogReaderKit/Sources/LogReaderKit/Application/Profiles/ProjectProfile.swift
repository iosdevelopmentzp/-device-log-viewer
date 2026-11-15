import Foundation
import LogReaderCore

public struct ProjectProfile: Sendable, Equatable, Identifiable {

    public let root: URL
    public let profile: LogProfile?
    public let errorText: String?
    public let modifiedAt: Date?

    public var id: String { root.path }

    public var name: String { profile?.name ?? root.lastPathComponent }

    public var hasProfile: Bool { profile != nil }

    public var profileURL: URL { Self.profileURL(in: root) }

    public static let profileFolder = ".logreader"
    public static let profileFileName = "profile.json"

    public init(root: URL, profile: LogProfile?, errorText: String?, modifiedAt: Date?) {
        self.root = root
        self.profile = profile
        self.errorText = errorText
        self.modifiedAt = modifiedAt
    }

    public static func profileURL(in root: URL) -> URL {
        root.appendingPathComponent(profileFolder, isDirectory: true).appendingPathComponent(profileFileName)
    }
}
