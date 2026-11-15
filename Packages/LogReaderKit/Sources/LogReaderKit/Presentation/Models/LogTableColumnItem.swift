import Foundation
import LogReaderCore

public struct LogTableColumnItem: Identifiable, Hashable, Sendable {

    public enum Kind: Hashable, Sendable {
        case number
        case time
        case delta
        case level
        case text
        case list
        case message
    }

    public let column: LogTableColumn
    public let kind: Kind
    public let title: String
    public let width: Int
    public let alignsTrailing: Bool
    public let facet: FacetColumn?
    public let attributeIndex: Int?

    public var id: String { column.rawValue }

    public var isMessage: Bool { kind == .message }

    public init(
        column: LogTableColumn,
        kind: Kind,
        title: String,
        width: Int,
        alignsTrailing: Bool,
        facet: FacetColumn?,
        attributeIndex: Int?
    ) {
        self.column = column
        self.kind = kind
        self.title = title
        self.width = width
        self.alignsTrailing = alignsTrailing
        self.facet = facet
        self.attributeIndex = attributeIndex
    }

    public static func all(in profile: LogProfile) -> [LogTableColumnItem] {
        let attributes = profile.attributes.enumerated().map { index, attribute in
            LogTableColumnItem(
                column: .attribute(attribute.id),
                kind: attribute.kind == .list ? .list : .text,
                title: attribute.title,
                width: attribute.columnWidth,
                alignsTrailing: false,
                facet: attribute.facet ? .attribute(attribute.id) : nil,
                attributeIndex: index
            )
        }
        return [
            LogTableColumnItem(column: .number, kind: .number, title: LogTableColumn.number.displayName(in: profile), width: 64, alignsTrailing: true, facet: nil, attributeIndex: nil),
            LogTableColumnItem(column: .time, kind: .time, title: LogTableColumn.time.displayName(in: profile), width: 104, alignsTrailing: false, facet: nil, attributeIndex: nil),
            LogTableColumnItem(column: .delta, kind: .delta, title: LogTableColumn.delta.displayName(in: profile), width: 70, alignsTrailing: true, facet: nil, attributeIndex: nil),
            LogTableColumnItem(column: .level, kind: .level, title: LogTableColumn.level.displayName(in: profile), width: 44, alignsTrailing: false, facet: .level, attributeIndex: nil)
        ] + attributes + [
            LogTableColumnItem(column: .message, kind: .message, title: LogTableColumn.message.displayName(in: profile), width: 900, alignsTrailing: false, facet: nil, attributeIndex: nil)
        ]
    }
}
