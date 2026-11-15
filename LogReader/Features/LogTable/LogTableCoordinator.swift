import AppKit
import LogReaderCore
import LogReaderKit
import SwiftUI

final class LogTableCoordinator: NSObject {

    private(set) weak var tableView: LogNSTableView?
    private weak var scrollView: NSScrollView?
    private(set) var presenter: LogTablePresenter?
    private var representable: LogTableView?
    private(set) var configurator = LogCellConfigurator(
        sheet: TextStyleSheet(fontSize: 12, wrapsByCharacter: false, fontFamily: .monospaced)
    )
    private var timeZoneMode: TimeZoneMode?
    private var expandsRows = false
    private var lineHeight: CGFloat = 16
    private var characterWidth: CGFloat = 7
    private var verticalInset: CGFloat = 3
    private let heightCache = LogTableRowHeightCache()
    private var cachedItem: (row: Int, item: LogRowItem)?
    private var isApplyingSelection = false
    private var isScrollingProgrammatically = false
    private var filterPopover: NSPopover?
    var columns: [LogTableColumnItem] = []
    private(set) var hiddenColumns: Set<LogTableColumn> = []

    private static let expandedMessageIdentifier = NSUserInterfaceItemIdentifier("message.expanded")
    private static let maxExpandedLines = 400
    private static let textContainerPadding: CGFloat = 12

    func install(tableView: LogNSTableView, scrollView: NSScrollView) {
        self.tableView = tableView
        self.scrollView = scrollView
        tableView.dataSource = self
        tableView.delegate = self
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
        tableView.target = self
        tableView.onCopy = { [weak self] in
            guard let self else { return }
            presenter?.copySelection()
        }
        tableView.onToggleGroup = { [weak self] isExpanding in
            guard let self else { return false }
            return setSelectedGroupExpanded(isExpanding)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    func update(from view: LogTableView) {
        representable = view
        tableView?.onToggleInspector = view.onToggleInspector
        configure(
            fontSize: view.fontSize,
            timeZoneMode: view.timeZoneMode,
            hiddenColumns: view.hiddenColumns,
            rowDensity: view.rowDensity,
            fontFamily: view.fontFamily,
            expandsRows: view.expandsRows
        )
        view.presenter.setCollapsesRepeats(view.collapsesRepeats)
        attach(view.presenter)
    }

    func detach() {
        if presenter?.receiver === self {
            presenter?.receiver = nil
        }
        presenter = nil
        representable = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - LogTableUpdateReceiver

extension LogTableCoordinator: LogTableUpdateReceiver {

    func apply(_ event: LogRowsEvent) {
        guard let tableView, let presenter else { return }
        cachedItem = nil
        switch event {
        case .reload:
            heightCache.update(recordCount: presenter.recordCount)
            installColumnsIfNeeded()
            updateHeaderTitles()
            tableView.reloadData()
            restoreSelection()
        case .inserted(let range):
            tableView.insertRows(at: IndexSet(integersIn: range), withAnimation: [])
            if presenter.isFollowing {
                scrollToEnd()
            }
        case .refreshRows:
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            tableView.enumerateAvailableRowViews { rowView, row in
                guard let rowView = rowView as? LogRowView, let item = presenter.row(at: row) else { return }
                rowView.isBookmarked = item.isBookmarked
            }
            tableView.reloadData(
                forRowIndexes: IndexSet(integersIn: visibleRows.location..<(visibleRows.location + visibleRows.length)),
                columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
            )
        case .select(let row):
            isApplyingSelection = true
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            isApplyingSelection = false
            scrollRowToCenter(row)
        case .scrollToEnd:
            scrollToEnd()
        }
    }
}

// MARK: - NSMenuDelegate

extension LogTableCoordinator: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let tableView, let presenter else { return }
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 else {
            menu.removeAllItems()
            return
        }
        if tableView.selectedRowIndexes.contains(clickedRow) == false {
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        }
        let entries = presenter.contextMenu(forRows: Array(tableView.selectedRowIndexes)) { [weak self] in
            guard let self else { return }
            representable?.onShowInspector()
        }
        LogRowMenuBuilder.build(entries, into: menu)
    }
}

// MARK: - NSTableViewDataSource

extension LogTableCoordinator: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        presenter?.rowCount ?? 0
    }
}

// MARK: - NSTableViewDelegate

extension LogTableCoordinator: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, let column = columnItem(for: tableColumn) else { return nil }
        let isExpandedMessage = expandsRows && column.isMessage
        let identifier = isExpandedMessage ? Self.expandedMessageIdentifier : tableColumn.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? LogCellView
            ?? LogCellView(identifier: identifier, isMultiline: isExpandedMessage, hasGroupControls: column.isMessage)
        guard let item = item(atRow: row) else { return nil }
        cell.verticalInset = verticalInset
        if isExpandedMessage {
            guard let message = presenter?.expandedMessage(at: row) else { return nil }
            configurator.configureExpanded(cell, message: message, maxLines: Self.maxExpandedLines)
        } else {
            configurator.configure(cell, column: column, item: item)
        }
        if column.isMessage {
            configureGroup(cell, item: item)
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard expandsRows, let presenter else { return tableView.rowHeight }
        return heightCache.height(
            row: row,
            presenter: presenter,
            lineHeight: lineHeight,
            verticalInset: verticalInset,
            columns: messageColumns,
            maxLines: Self.maxExpandedLines
        )
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard let facet = columnItem(for: tableColumn)?.facet,
              let presenter,
              let headerView = tableView.headerView else { return }
        let columnIndex = tableView.column(withIdentifier: tableColumn.identifier)
        guard columnIndex >= 0 else { return }
        filterPopover?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: FacetFilterView(model: presenter.facetFilterViewModel(for: facet))
        )
        popover.show(relativeTo: headerView.headerRect(ofColumn: columnIndex), of: headerView, preferredEdge: .maxY)
        filterPopover = popover
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        guard expandsRows, let tableView else { return }
        let column = notification.userInfo?["NSTableColumn"] as? NSTableColumn
        guard column?.identifier == Self.messageIdentifier else { return }
        heightCache.scheduleRecalculation(for: tableView)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = tableView.makeView(withIdentifier: LogRowView.reuseIdentifier, owner: self) as? LogRowView
            ?? LogRowView(frame: .zero)
        let item = item(atRow: row)
        rowView.isAlternate = row % 2 == 1
        rowView.isBookmarked = item?.isBookmarked ?? false
        rowView.tint = item.flatMap { $0.isFindMatch ? LogColors.findRowTint : LevelColors.rowTint(for: $0) }
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard isApplyingSelection == false, let tableView, let presenter else { return }
        presenter.selectionDidChange(rows: Array(tableView.selectedRowIndexes))
    }
}

// MARK: - Private

private extension LogTableCoordinator {

    var messageColumns: Int {
        guard let column = tableView?.tableColumn(withIdentifier: Self.messageIdentifier), characterWidth > 0 else { return 80 }
        return max(10, Int((column.width - LogCellView.horizontalInset * 2 - Self.textContainerPadding) / characterWidth))
    }

    var isAtBottom: Bool {
        guard let scrollView, let documentView = scrollView.documentView else { return true }
        let visibleMaxY = scrollView.contentView.bounds.maxY
        let rowHeight = tableView?.rowHeight ?? 16
        return visibleMaxY >= documentView.frame.height - rowHeight * 1.5
    }

    func item(atRow row: Int) -> LogRowItem? {
        if let cachedItem, cachedItem.row == row {
            return cachedItem.item
        }
        guard let item = presenter?.row(at: row) else { return nil }
        cachedItem = (row, item)
        return item
    }

    func configure(
        fontSize: Double,
        timeZoneMode: TimeZoneMode,
        hiddenColumns: Set<LogTableColumn>,
        rowDensity: RowDensity,
        fontFamily: FontFamily,
        expandsRows: Bool
    ) {
        guard let tableView else { return }
        self.hiddenColumns = hiddenColumns
        applyHiddenColumns()
        let verticalInset = Self.verticalInset(for: rowDensity)
        let isLayoutChanged = fontSize != configurator.sheet.fontSize
            || fontFamily != configurator.sheet.fontFamily
            || verticalInset != self.verticalInset
            || expandsRows != self.expandsRows
        guard isLayoutChanged || timeZoneMode != self.timeZoneMode else { return }
        self.timeZoneMode = timeZoneMode
        self.expandsRows = expandsRows
        self.verticalInset = verticalInset
        configurator = LogCellConfigurator(
            sheet: TextStyleSheet(fontSize: fontSize, wrapsByCharacter: false, fontFamily: fontFamily)
        )
        let font = configurator.sheet.font
        lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        characterWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        tableView.rowHeight = lineHeight + verticalInset * 2
        heightCache.removeAll()
        reloadKeepingPosition()
    }

    static func verticalInset(for density: RowDensity) -> CGFloat {
        switch density {
        case .compact: 1
        case .comfortable: 3
        }
    }

    func attach(_ newPresenter: LogTablePresenter) {
        guard newPresenter !== presenter else { return }
        if presenter?.receiver === self {
            presenter?.receiver = nil
        }
        presenter = newPresenter
        newPresenter.receiver = self
        cachedItem = nil
        heightCache.removeAll()
        heightCache.update(recordCount: newPresenter.recordCount)
        installColumnsIfNeeded()
        updateHeaderTitles()
        filterPopover?.close()
        tableView?.reloadData()
        scrollToEnd()
    }

    func reloadKeepingPosition() {
        guard let tableView else { return }
        cachedItem = nil
        let anchorRow = tableView.selectedRowIndexes.last ?? tableView.rows(in: tableView.visibleRect).location
        tableView.reloadData()
        guard let presenter, presenter.isFollowing == false, anchorRow < tableView.numberOfRows else {
            scrollToEnd()
            return
        }
        scrollRowToCenter(anchorRow)
    }

    func restoreSelection() {
        guard let tableView, let presenter else { return }
        let rows = presenter.selectedRows
        guard rows.isEmpty == false else { return }
        isApplyingSelection = true
        tableView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        isApplyingSelection = false
    }

    func scrollToEnd() {
        guard let tableView, tableView.numberOfRows > 0 else { return }
        isScrollingProgrammatically = true
        tableView.scrollRowToVisible(tableView.numberOfRows - 1)
        isScrollingProgrammatically = false
    }

    func scrollRowToCenter(_ row: Int) {
        guard let tableView, let scrollView else { return }
        let rowRect = tableView.rect(ofRow: row)
        let visibleHeight = scrollView.contentView.bounds.height
        let targetY = max(0, rowRect.midY - visibleHeight / 2)
        isScrollingProgrammatically = true
        scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.minX, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        isScrollingProgrammatically = false
    }

    @objc func boundsDidChange() {
        guard isScrollingProgrammatically == false, let presenter else { return }
        presenter.setFollowing(isAtBottom)
    }
}
