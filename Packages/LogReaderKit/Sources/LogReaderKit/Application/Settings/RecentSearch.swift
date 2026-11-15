import Foundation
import LogReaderCore

public struct RecentSearch: Codable, Equatable, Identifiable, Sendable {

    private enum CodingKeys: String, CodingKey {
        case id, text, mode, scope, isRegex, date, isPinned
    }

    public let id: UUID
    public let text: String
    public let mode: SearchMode
    public let scope: SearchScope
    public let isRegex: Bool
    public var date: Date
    public var isPinned: Bool

    public init(id: UUID, text: String, mode: SearchMode, scope: SearchScope, isRegex: Bool, date: Date, isPinned: Bool) {
        self.id = id
        self.text = text
        self.mode = mode
        self.scope = scope
        self.isRegex = isRegex
        self.date = date
        self.isPinned = isPinned
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.mode = try container.decode(SearchMode.self, forKey: .mode)
        self.scope = try SearchScope.decode(from: container, forKey: .scope)
        self.isRegex = try container.decodeIfPresent(Bool.self, forKey: .isRegex) ?? false
        self.date = try container.decode(Date.self, forKey: .date)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    public func isSameSearch(as other: RecentSearch) -> Bool {
        text == other.text && mode == other.mode && scope == other.scope
    }
}
