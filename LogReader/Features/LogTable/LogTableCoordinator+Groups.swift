import AppKit
import LogReaderKit

extension LogTableCoordinator {

    func configureGroup(_ cell: LogCellView, item: LogRowItem) {
        configurator.configureGroup(cell, item: item) { [weak self] cell in
            guard let self else { return }
            toggleGroup(of: cell)
        }
    }

    func setSelectedGroupExpanded(_ isExpanded: Bool) -> Bool {
        guard let tableView, let presenter, tableView.selectedRowIndexes.count == 1 else { return false }
        let row = tableView.selectedRow
        guard let item = presenter.row(at: row), item.repeatCount != nil, item.isGroupExpanded != isExpanded else { return false }
        presenter.toggleGroup(atRow: row)
        return true
    }
}

// MARK: - Private

private extension LogTableCoordinator {

    func toggleGroup(of cell: NSView) {
        guard let tableView, let presenter else { return }
        let row = tableView.row(for: cell)
        guard row >= 0 else { return }
        presenter.toggleGroup(atRow: row)
    }
}
