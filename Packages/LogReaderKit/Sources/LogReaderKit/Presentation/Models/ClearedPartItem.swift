import Foundation

public struct ClearedPartItem: Identifiable, Hashable, Sendable {

    public enum Kind: Hashable, Sendable {
        case before
        case after
        case selected
    }

    public let id: String
    public let title: String
    public let kind: Kind

    public init(id: String, title: String, kind: Kind) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}
