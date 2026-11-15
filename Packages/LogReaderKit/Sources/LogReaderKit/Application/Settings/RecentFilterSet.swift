import Foundation
import LogReaderCore

public struct RecentFilterSet: Codable, Equatable, Identifiable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case id, facets, bookmarksOnly, date
    }

    public let id: UUID
    public let facets: FacetSelection
    public let bookmarksOnly: Bool
    public var date: Date

    public init(id: UUID, facets: FacetSelection, bookmarksOnly: Bool, date: Date) {
        self.id = id
        self.facets = facets
        self.bookmarksOnly = bookmarksOnly
        self.date = date
    }

    public func isSameFilter(as other: RecentFilterSet) -> Bool {
        facets == other.facets && bookmarksOnly == other.bookmarksOnly
    }
}
