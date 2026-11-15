import Foundation
import LogReaderCore

public struct FilterPreset: Codable, Identifiable, Equatable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case id, name, searchText, searchMode, searchScope, isRegex, facets, bookmarksOnly, extraTerms
    }

    public let id: UUID
    public var name: String
    public let searchText: String
    public let searchMode: SearchMode
    public let searchScope: SearchScope
    public let isRegex: Bool
    public let facets: FacetSelection
    public let bookmarksOnly: Bool
    public let extraTerms: [SearchTerm]

    public init(
        id: UUID,
        name: String,
        searchText: String,
        searchMode: SearchMode,
        searchScope: SearchScope,
        isRegex: Bool,
        facets: FacetSelection,
        bookmarksOnly: Bool,
        extraTerms: [SearchTerm]
    ) {
        self.id = id
        self.name = name
        self.searchText = searchText
        self.searchMode = searchMode
        self.searchScope = searchScope
        self.isRegex = isRegex
        self.facets = facets
        self.bookmarksOnly = bookmarksOnly
        self.extraTerms = extraTerms
    }
}

// MARK: - Decodable

extension FilterPreset {

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.searchText = try container.decode(String.self, forKey: .searchText)
        self.searchMode = try container.decode(SearchMode.self, forKey: .searchMode)
        self.searchScope = try SearchScope.decode(from: container, forKey: .searchScope)
        self.isRegex = try container.decodeIfPresent(Bool.self, forKey: .isRegex) ?? false
        self.facets = try container.decode(FacetSelection.self, forKey: .facets)
        self.bookmarksOnly = try container.decode(Bool.self, forKey: .bookmarksOnly)
        self.extraTerms = try container.decodeIfPresent([SearchTerm].self, forKey: .extraTerms) ?? []
    }
}
