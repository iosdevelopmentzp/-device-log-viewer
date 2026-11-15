import Foundation

public struct RecentFilterItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String

    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}
