import Foundation

public struct ColumnOption: Identifiable, Hashable, Sendable {
    public let column: LogTableColumn
    public let title: String
    public let isOn: Bool
    public let canHide: Bool

    public var id: LogTableColumn { column }

    public init(column: LogTableColumn, title: String, isOn: Bool, canHide: Bool) {
        self.column = column
        self.title = title
        self.isOn = isOn
        self.canHide = canHide
    }
}
