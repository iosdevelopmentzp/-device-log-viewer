import Foundation
import LogReaderCore

extension SearchScope {

    private static let legacyIDs = ["message", "tags", "category", "source", "level"]

    init?(legacyRawValue: Int) {
        let ids = Self.legacyIDs.enumerated().filter { legacyRawValue & (1 << $0.offset) != 0 }.map(\.element)
        guard ids.isEmpty == false else { return nil }
        self.init(ids: Set(ids))
    }

    static func decode<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> SearchScope {
        if let legacy = try? container.decode(Int.self, forKey: key) {
            return SearchScope(legacyRawValue: legacy) ?? .message
        }
        return try container.decode(SearchScope.self, forKey: key)
    }
}
