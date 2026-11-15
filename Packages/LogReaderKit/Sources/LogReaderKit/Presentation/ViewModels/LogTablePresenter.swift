import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class LogTablePresenter {

    @ObservationIgnored public weak var receiver: (any LogTableUpdateReceiver)?

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let copyEntries: CopyEntries
    @ObservationIgnored private let openSource: OpenSource
    @ObservationIgnored private var messageBuilder: MessageTextBuilder
    @ObservationIgnored private var collapser: RowCollapser?
    @ObservationIgnored private let entryText: LogEntryText

    public var rowCount: Int { collapser?.rowCount ?? session.visible.count }

    public var collapsesRepeats: Bool { collapser != nil }

    public var recordCount: Int { session.content.records.count }

    public var isFollowing: Bool { session.isFollowing }

    public var columns: [LogTableColumnItem] { LogTableColumnItem.all(in: session.profile) }

    public var selectedRows: [Int] {
        let selected = Set(session.selectedRecords)
        guard selected.isEmpty == false else { return [] }
        guard let collapser else {
            return session.visible.indices.filter { selected.contains(session.visible[$0]) }
        }
        return Set(selected.compactMap(collapser.rowIndex(ofRecord:))).sorted()
    }

    public init(session: LogSession, settings: AppSettings, copyEntries: CopyEntries, openSource: OpenSource) {
        self.session = session
        self.settings = settings
        self.copyEntries = copyEntries
        self.openSource = openSource
        self.messageBuilder = MessageTextBuilder(highlight: [])
        self.entryText = LogEntryText(profile: session.profile)
    }

    public func start() {
        updateHighlight()
        session.rowsObserver = self
    }

    public func stop() {
        guard session.rowsObserver === self else { return }
        session.rowsObserver = nil
    }

    public func recordIndex(atRow row: Int) -> Int? {
        guard let collapser else { return session.recordIndex(atRow: row) }
        return collapser.recordIndex(atRow: row)
    }

    public func row(at row: Int) -> LogRowItem? {
        guard let index = recordIndex(atRow: row), let record = session.record(at: index) else { return nil }
        let group = groupState(atRow: row)
        let timeFormatter = TimeTextFormatter(timeZoneMode: settings.timeZoneMode)
        let profile = session.profile
        let level = record.level.flatMap(profile.rule(of:))
        return LogRowItem(
            number: index + 1,
            numberText: String(index + 1),
            time: timeFormatter.time(record.timestamp),
            fullDate: timeFormatter.fullDate(record.timestamp),
            delta: DeltaTextFormatter.text(from: session.previousRecord(before: index)?.timestamp, to: record.timestamp),
            levelStyle: level?.style,
            levelCode: level?.code ?? "",
            highlightsRow: level?.highlightsRow ?? false,
            attributes: AttributeText.texts(of: record, profile: profile),
            message: messageBuilder.rowMessage(for: record, profile: profile),
            isBookmarked: session.isBookmarked(record),
            isFindMatch: session.findMatchSet.contains(index),
            repeatCount: group.repeatCount,
            repeatCountText: group.repeatCount.map(Self.repeatCountText) ?? "",
            isGroupExpanded: group.isExpanded,
            isGroupMember: group.isMember
        )
    }

    public func expandedMessage(at row: Int, columns: Int, maxLines: Int) -> ExpandedMessageItem? {
        guard let record = record(atRow: row) else { return nil }
        let parts = messageAndBody(of: record)
        return messageBuilder.expandedMessage(
            message: parts.message,
            body: parts.body,
            style: MessageTextBuilder.messageStyle(of: record, in: session.profile),
            columns: columns,
            maxLines: maxLines
        )
    }

    public func lineCount(row: Int, columns: Int, maxLines: Int) -> Int {
        guard let record = record(atRow: row) else { return 1 }
        return session.content.withBytes(of: record) { bytes in
            entryText.wrappedLineCount(bytes, record: record, columns: columns, maxLines: maxLines)
        }
    }

    public func groupIndent(atRow row: Int) -> GroupIndent {
        switch collapser?.row(at: row) {
        case .group(_, let indices, _):
            .group(badge: Self.repeatCountText(indices.count))
        case .member:
            .member
        case .single, nil:
            .none
        }
    }

    public func isFacetActive(_ column: FacetColumn) -> Bool {
        session.filterState.facets.isActive(column)
    }

    public func headerTitle(for column: FacetColumn) -> String {
        let facets = session.filterState.facets
        let title = column.columnTitle(in: session.profile)
        guard facets.isActive(column) else { return title + " ▾" }
        switch facets.mode(of: column) {
        case .include: return title + " ◉"
        case .exclude: return title + " ⊘"
        }
    }

    public func headerToolTip(for column: FacetColumn) -> String {
        let facets = session.filterState.facets
        guard facets.isActive(column) else { return "Click to filter by \(column.displayName(in: session.profile).lowercased())" }
        let count = facets.values(in: column).count
        let values = count == 1 ? "1 value" : "\(count) values"
        switch facets.mode(of: column) {
        case .include: return "Showing only \(values). Click to change."
        case .exclude: return "Hiding \(values). Click to change."
        }
    }

    public func facetFilterViewModel(for column: FacetColumn) -> FacetFilterViewModel {
        FacetFilterViewModel(session: session, column: column)
    }

    public func contextMenu(forRows rows: [Int], showDetails: @escaping @MainActor () -> Void) -> [ContextMenuEntry] {
        RowContextMenuModel.entries(
            session: session,
            recordIndices: rows.compactMap(recordIndex(atRow:)),
            copyEntries: copyEntries,
            openSource: openSource,
            settings: settings,
            showDetails: showDetails
        )
    }

    public func selectionDidChange(rows: [Int]) {
        session.selectedRecords = rows.compactMap(recordIndex(atRow:))
    }

    public func setCollapsesRepeats(_ collapsesRepeats: Bool) {
        guard collapsesRepeats != self.collapsesRepeats else { return }
        collapser = collapsesRepeats ? RowCollapser() : nil
        rebuildCollapser()
        receiver?.apply(.reload)
    }

    public func toggleGroup(atRow row: Int) {
        guard collapser?.toggleGroup(atRow: row) == true else { return }
        receiver?.apply(.reload)
    }

    public func setFollowing(_ isFollowing: Bool) {
        guard session.isFollowing != isFollowing else { return }
        session.isFollowing = isFollowing
    }

    public func copySelection() {
        copyEntries.copySelection(of: session)
    }
}

// MARK: - LogRowsObserver

extension LogTablePresenter: LogRowsObserver {

    public func handle(_ event: LogRowsEvent) {
        switch event {
        case .reload:
            updateHighlight()
            rebuildCollapser()
            receiver?.apply(event)
        case .inserted(let range):
            insertRows(visibleRange: range)
        case .select(let row):
            session.selectedRecords = session.recordIndex(atRow: row).map { [$0] } ?? []
            select(visibleRow: row)
        case .refreshRows, .scrollToEnd:
            receiver?.apply(event)
        }
    }
}

// MARK: - Private

private extension LogTablePresenter {

    func updateHighlight() {
        messageBuilder = MessageTextBuilder(highlight: session.filterState.highlightQueries)
    }

    static func repeatCountText(_ count: Int) -> String {
        "×\(count)"
    }

    func record(atRow row: Int) -> LogRecord? {
        recordIndex(atRow: row).flatMap(session.record(at:))
    }

    func messageAndBody(of record: LogRecord) -> (message: String, body: String) {
        session.content.withBytes(of: record) { entryText.messageAndBody($0, record: record) }
    }

    func groupState(atRow row: Int) -> (repeatCount: Int?, isExpanded: Bool, isMember: Bool) {
        switch collapser?.row(at: row) {
        case .group(_, let indices, let isExpanded):
            (indices.count, isExpanded, false)
        case .member:
            (nil, false, true)
        case .single, nil:
            (nil, false, false)
        }
    }

    func groupKey(of recordIndex: Int) -> String {
        guard let record = session.record(at: recordIndex) else { return "" }
        return record.message + "\u{1F}" + (record.level.map { String($0.index) } ?? "")
    }

    func rebuildCollapser() {
        let visible = session.visible
        collapser?.rebuild(recordIndices: visible) { groupKey(of: $0) }
    }

    func insertRows(visibleRange: Range<Int>) {
        guard collapser != nil else {
            receiver?.apply(.inserted(visibleRange))
            return
        }
        let indices = Array(session.visible[visibleRange])
        guard let result = collapser?.append(recordIndices: indices, key: { groupKey(of: $0) }) else { return }
        if result.insertedRows.isEmpty == false {
            receiver?.apply(.inserted(result.insertedRows))
        }
        if result.changedRow != nil {
            receiver?.apply(.refreshRows)
        }
    }

    func select(visibleRow: Int) {
        guard collapser != nil, let recordIndex = session.recordIndex(atRow: visibleRow) else {
            receiver?.apply(.select(row: visibleRow))
            return
        }
        let shownRecord = collapser?.rowIndex(ofRecord: recordIndex).flatMap { collapser?.recordIndex(atRow: $0) }
        if shownRecord != recordIndex, collapser?.expandGroup(containing: recordIndex) == true {
            receiver?.apply(.reload)
        }
        guard let row = collapser?.rowIndex(ofRecord: recordIndex) else { return }
        receiver?.apply(.select(row: row))
    }
}
