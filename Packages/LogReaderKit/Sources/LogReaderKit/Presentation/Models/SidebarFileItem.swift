import Foundation

public struct SidebarFileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let title: String
    public let sizeText: String
    public let matchText: String
    public let isNewest: Bool
    public let canDelete: Bool

    public var id: String { url.path }

    public init(url: URL, title: String, sizeText: String, matchText: String, isNewest: Bool, canDelete: Bool) {
        self.url = url
        self.title = title
        self.sizeText = sizeText
        self.matchText = matchText
        self.isNewest = isNewest
        self.canDelete = canDelete
    }
}
