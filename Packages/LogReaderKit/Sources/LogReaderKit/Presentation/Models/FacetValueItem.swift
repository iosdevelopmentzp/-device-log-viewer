import Foundation

public struct FacetValueItem: Identifiable, Hashable, Sendable {
    public let value: String
    public let title: String
    public let count: Int
    public let countText: String
    public let isSelected: Bool
    public let actionTitle: String
    public let actionHelp: String

    public var id: String { value }

    public init(
        value: String,
        title: String,
        count: Int,
        countText: String,
        isSelected: Bool,
        actionTitle: String,
        actionHelp: String
    ) {
        self.value = value
        self.title = title
        self.count = count
        self.countText = countText
        self.isSelected = isSelected
        self.actionTitle = actionTitle
        self.actionHelp = actionHelp
    }
}
