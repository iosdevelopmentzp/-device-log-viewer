import Foundation

public struct SearchTermItem: Identifiable, Equatable, Sendable {

    public let id: Int
    public let text: String
    public let isNegated: Bool

    public init(id: Int, text: String, isNegated: Bool) {
        self.id = id
        self.text = text
        self.isNegated = isNegated
    }
}
