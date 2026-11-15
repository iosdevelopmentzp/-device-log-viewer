import AppKit
import LogReaderKit
import SwiftUI

struct LogTableView: NSViewRepresentable {

    let presenter: LogTablePresenter
    let fontSize: Double
    let timeZoneMode: TimeZoneMode
    let hiddenColumns: Set<LogTableColumn>
    let rowDensity: RowDensity
    let fontFamily: FontFamily
    let expandsRows: Bool
    let collapsesRepeats: Bool
    let onToggleInspector: () -> Void
    let onShowInspector: () -> Void

    func makeCoordinator() -> LogTableCoordinator {
        LogTableCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = LogNSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = LogColors.background
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.gridStyleMask = []
        tableView.autosaveName = "LogTable"
        presenter.columns.forEach { tableView.addTableColumn($0.makeTableColumn()) }
        tableView.autosaveTableColumns = true

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.install(tableView: tableView, scrollView: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(from: self)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: LogTableCoordinator) {
        coordinator.detach()
    }
}
