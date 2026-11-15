import Foundation

public struct SearchScope: Sendable, Hashable, Codable {

    public private(set) var ids: Set<String>

    public static let messageID = "message"
    public static let levelID = "level"
    public static let message = SearchScope(ids: [messageID])

    public var isEmpty: Bool { ids.isEmpty }
    public var includesMessage: Bool { ids.contains(Self.messageID) }
    public var includesLevel: Bool { ids.contains(Self.levelID) }
    public var attributeIDs: Set<String> { ids.subtracting([Self.messageID, Self.levelID]) }

    public init(ids: Set<String>) {
        self.ids = ids
    }

    public static func optionIDs(in profile: LogProfile) -> [String] {
        [messageID] + profile.attributes.filter(\.searchable).map(\.id) + [levelID]
    }

    public func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    public mutating func insert(_ id: String) {
        ids.insert(id)
    }

    public mutating func remove(_ id: String) {
        ids.remove(id)
    }

    public mutating func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    public func sorted(in profile: LogProfile) -> [String] {
        Self.optionIDs(in: profile).filter(ids.contains)
    }
}
