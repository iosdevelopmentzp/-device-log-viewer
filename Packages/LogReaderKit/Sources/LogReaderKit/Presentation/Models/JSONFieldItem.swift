public struct JSONFieldItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let tree: JSONTreeNode

    public init(id: String, key: String, tree: JSONTreeNode) {
        self.id = id
        self.key = key
        self.tree = tree
    }
}
