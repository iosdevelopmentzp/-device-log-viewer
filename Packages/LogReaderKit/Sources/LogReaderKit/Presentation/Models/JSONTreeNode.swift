public struct JSONTreeNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let valueText: String
    public let kind: JSONValueKind
    public let children: [JSONTreeNode]

    public var isContainer: Bool { kind == .object || kind == .array }

    public init(id: String, key: String, valueText: String, kind: JSONValueKind, children: [JSONTreeNode]) {
        self.id = id
        self.key = key
        self.valueText = valueText
        self.kind = kind
        self.children = children
    }
}
