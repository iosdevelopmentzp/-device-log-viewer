import AppKit
import LogReaderKit

extension LogTableColumnItem {

    var identifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier(id) }

    var alignment: NSTextAlignment { alignsTrailing ? .right : .left }

    func makeTableColumn() -> NSTableColumn {
        let tableColumn = NSTableColumn(identifier: identifier)
        tableColumn.title = title
        tableColumn.width = CGFloat(width)
        tableColumn.minWidth = isMessage ? 200 : 30
        tableColumn.headerCell.alignment = alignment
        tableColumn.resizingMask = .userResizingMask
        return tableColumn
    }
}
