import Foundation
import LogReaderCore

public struct FilterChipItem: Identifiable, Hashable, Sendable {

    public enum Kind: Hashable, Sendable {
        case search
        case levels
        case facet(FacetColumn)
        case bookmarks
        case timeRange
    }

    public let id: String
    public let title: String
    public let kind: Kind
    public let isExclusion: Bool

    public init(id: String, title: String, kind: Kind, isExclusion: Bool) {
        self.id = id
        self.title = title
        self.kind = kind
        self.isExclusion = isExclusion
    }
}
