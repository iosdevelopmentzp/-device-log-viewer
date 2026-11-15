import Foundation

public struct SidebarAppItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let bundleID: String
    public let logsURL: URL
    public let files: [SidebarFileItem]
    public let newestFileURL: URL?
    public let canDelete: Bool

    public init(id: String, bundleID: String, logsURL: URL, files: [SidebarFileItem], newestFileURL: URL?, canDelete: Bool) {
        self.id = id
        self.bundleID = bundleID
        self.logsURL = logsURL
        self.files = files
        self.newestFileURL = newestFileURL
        self.canDelete = canDelete
    }
}
