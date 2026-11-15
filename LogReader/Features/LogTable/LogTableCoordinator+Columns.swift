import AppKit
import LogReaderKit

extension LogTableCoordinator {

    static let messageIdentifier = NSUserInterfaceItemIdentifier(LogTableColumn.message.rawValue)

    func columnItem(for tableColumn: NSTableColumn) -> LogTableColumnItem? {
        columns.first { $0.id == tableColumn.identifier.rawValue }
    }

    func installColumnsIfNeeded() {
        guard let tableView, let presenter else { return }
        let items = presenter.columns
        columns = items
        let installed = Set(tableView.tableColumns.map(\.identifier.rawValue))
        guard installed != Set(items.map(\.id)) else { return }
        tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
        items.forEach { tableView.addTableColumn($0.makeTableColumn()) }
        applyHiddenColumns()
    }

    func applyHiddenColumns() {
        guard let tableView else { return }
        for tableColumn in tableView.tableColumns {
            tableColumn.isHidden = hiddenColumns.contains(LogTableColumn(rawValue: tableColumn.identifier.rawValue))
        }
    }

    func updateHeaderTitles() {
        guard let tableView, let presenter else { return }
        for item in columns {
            guard let tableColumn = tableView.tableColumn(withIdentifier: item.identifier) else { continue }
            guard let facet = item.facet else {
                tableColumn.title = item.title
                continue
            }
            tableColumn.title = presenter.headerTitle(for: facet)
            tableColumn.headerToolTip = presenter.headerToolTip(for: facet)
        }
        tableView.headerView?.needsDisplay = true
    }
}
