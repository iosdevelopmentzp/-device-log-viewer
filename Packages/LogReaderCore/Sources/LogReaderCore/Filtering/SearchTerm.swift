import Foundation

public struct SearchTerm: Sendable, Equatable, Codable {

    public let text: String
    public let isNegated: Bool

    public init(text: String, isNegated: Bool) {
        self.text = text
        self.isNegated = isNegated
    }
}
