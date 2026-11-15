import Foundation

public struct SidebarDeviceItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let runtime: String
    public let subtitle: String
    public let symbolName: String?
    public let isBooted: Bool
    public let folderURL: URL
    public let apps: [SidebarAppItem]
    public let canDelete: Bool
    public let copyIDTitle: String
    public let copyNameTitle: String
    public let showFolderTitle: String

    public init(
        id: String,
        name: String,
        runtime: String,
        subtitle: String,
        symbolName: String?,
        isBooted: Bool,
        folderURL: URL,
        apps: [SidebarAppItem],
        canDelete: Bool,
        copyIDTitle: String,
        copyNameTitle: String,
        showFolderTitle: String
    ) {
        self.id = id
        self.name = name
        self.runtime = runtime
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.isBooted = isBooted
        self.folderURL = folderURL
        self.apps = apps
        self.canDelete = canDelete
        self.copyIDTitle = copyIDTitle
        self.copyNameTitle = copyNameTitle
        self.showFolderTitle = showFolderTitle
    }
}
