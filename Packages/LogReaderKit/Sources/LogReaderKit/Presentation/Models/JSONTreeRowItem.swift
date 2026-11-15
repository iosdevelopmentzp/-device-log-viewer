public struct JSONTreeRowItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let depth: Int
    public let key: String
    public let valueText: String
    public let kind: JSONValueKind
    public let valueStyle: TextStyle
    public let isContainer: Bool
    public let isExpanded: Bool

    public init(
        id: String,
        depth: Int,
        key: String,
        valueText: String,
        kind: JSONValueKind,
        valueStyle: TextStyle,
        isContainer: Bool,
        isExpanded: Bool
    ) {
        self.id = id
        self.depth = depth
        self.key = key
        self.valueText = valueText
        self.kind = kind
        self.valueStyle = valueStyle
        self.isContainer = isContainer
        self.isExpanded = isExpanded
    }
}
