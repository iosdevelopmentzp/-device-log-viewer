import Foundation

public struct SearchScopeOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let isOn: Bool

    public init(id: String, title: String, isOn: Bool) {
        self.id = id
        self.title = title
        self.isOn = isOn
    }
}
