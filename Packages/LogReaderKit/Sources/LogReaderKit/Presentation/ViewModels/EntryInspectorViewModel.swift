import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class EntryInspectorViewModel {

    public struct LoadKey: Hashable, Sendable {
        let offset: Int
        let length: Int
        let searchText: String
        let isRegex: Bool
        let highlightTerms: [String]
        let entrySearchText: String
        let fontSize: Double
    }

    struct LoadedEntry {
        let offset: Int
        let length: Int
        let rawText: String
        let details: LogEntryDetails
        let jsonFields: [JSONFieldItem]
        let nodesByID: [String: JSONTreeNode]
    }

    public var entrySearchText = ""
    public private(set) var currentMatch = 0
    public private(set) var layout: EntryTextLayout?
    public private(set) var jsonFields: [JSONFieldItem] = []
    public private(set) var expandedNodeIDs: Set<String> = []

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let copyEntries: CopyEntries
    @ObservationIgnored private let openSourceUseCase: OpenSource
    private var loaded: LoadedEntry?

    nonisolated private static let jsonNodeLimit = 5_000

    public var hasSelection: Bool { session.primarySelection != nil }

    public var canOpenSource: Bool {
        session.primarySelection.flatMap { session.profile.sourceReference(of: $0) } != nil
    }

    public var isLoading: Bool {
        guard let record = session.primarySelection else { return false }
        return loadedEntry(for: record) == nil || layout == nil
    }

    public var header: EntryHeaderItem? {
        guard let record = session.primarySelection, let index = session.selectedRecords.last else { return nil }
        let profile = session.profile
        let timeFormatter = TimeTextFormatter(timeZoneMode: settings.timeZoneMode)
        let sizeText = FileSizeText.memory(Int64(record.length))
        let attributeRows = profile.attributes.enumerated().map { attributeIndex, attribute in
            EntryHeaderItem.MetadataRow(
                title: attribute.title,
                value: AttributeText.text(profile.value(of: record, attribute: attributeIndex), rule: attribute),
                isSource: attribute.role == .source
            )
        }
        let rows = [EntryHeaderItem.MetadataRow(title: "Time", value: timeFormatter.fullDate(record.timestamp), isSource: false)]
            + attributeRows
            + [EntryHeaderItem.MetadataRow(title: "Size", value: sizeText, isSource: false)]
        let level = record.level.flatMap(profile.rule(of:))
        return EntryHeaderItem(
            number: index + 1,
            numberText: "#\(index + 1)",
            levelStyle: level?.style,
            levelTitle: level?.title ?? "",
            isBookmarked: session.isBookmarked(record),
            metadata: rows.filter { $0.value.isEmpty == false },
            sizeText: sizeText,
            hasSource: profile.sourceReference(of: record) != nil,
            openSourceTitle: profile.source.openTitle
        )
    }

    public var focusRange: NSRange? {
        guard let matches = layout?.localMatches, matches.indices.contains(currentMatch) else { return nil }
        return matches[currentMatch]
    }

    public var showsMatchControls: Bool { entrySearchText.isEmpty == false }

    public var matchCountText: String {
        let count = localMatchCount
        guard count > 0 else { return "No matches" }
        return "\(currentMatch + 1)/\(count)"
    }

    public var canNavigateMatches: Bool { localMatchCount > 0 }

    public var loadKey: LoadKey? {
        guard let record = session.primarySelection else { return nil }
        return LoadKey(
            offset: record.offset,
            length: record.length,
            searchText: session.filterState.searchText,
            isRegex: session.filterState.isRegex,
            highlightTerms: session.filterState.activeExtraTerms.filter { $0.isNegated == false }.map(\.text),
            entrySearchText: entrySearchText,
            fontSize: settings.fontSize
        )
    }

    public var showsJSONTree: Bool {
        get { settings.inspectorShowsJSONTree }
        set { settings.inspectorShowsJSONTree = newValue }
    }

    public var showsTreeSection: Bool { entrySearchText.isEmpty }

    public var copyItems: [ContextMenuItem] {
        guard let loaded = currentLoadedEntry else { return [] }
        let fieldItems = loaded.details.fields.map { field in
            let value = field.prettyValue ?? field.value
            return ContextMenuItem(title: "Copy “\(field.key.isEmpty ? "text" : field.key)”", isEnabled: true) { [copyEntries] in
                copyEntries.copy(text: value)
            }
        }
        return [
            ContextMenuItem(title: "Copy Entry", isEnabled: true) { [weak self] in
                guard let self else { return }
                copyEntry()
            },
            ContextMenuItem(title: "Copy Message", isEnabled: true) { [weak self] in
                guard let self else { return }
                copyMessage()
            },
            ContextMenuItem(title: "Copy as JSON", isEnabled: true) { [weak self] in
                guard let self else { return }
                copyJSON()
            }
        ] + fieldItems
    }

    public init(session: LogSession, settings: AppSettings, copyEntries: CopyEntries, openSource: OpenSource) {
        self.session = session
        self.settings = settings
        self.copyEntries = copyEntries
        self.openSourceUseCase = openSource
    }

    public func load() async {
        guard let key = loadKey, let record = session.primarySelection else {
            layout = nil
            jsonFields = []
            expandedNodeIDs = []
            return
        }
        let entry: LoadedEntry
        if let cached = loadedEntry(for: record) {
            entry = cached
        } else {
            let rawText = session.text(of: record)
            let profile = session.profile
            entry = await Task.detached(priority: .userInitiated) {
                Self.makeLoadedEntry(record: record, rawText: rawText, profile: profile)
            }.value
            guard Task.isCancelled == false else { return }
            jsonFields = entry.jsonFields
            expandedNodeIDs = Self.defaultExpandedIDs(of: entry.jsonFields)
        }
        let builder = EntryTextLayoutBuilder(
            globalQueries: session.filterState.highlightQueries,
            localQuery: TextQuery(key.entrySearchText)
        )
        loaded = entry
        currentMatch = 0
        layout = builder.layout(for: entry.details)
    }

    public func nextMatch() {
        let count = localMatchCount
        guard count > 0 else { return }
        currentMatch = (currentMatch + 1) % count
    }

    public func previousMatch() {
        let count = localMatchCount
        guard count > 0 else { return }
        currentMatch = (currentMatch - 1 + count) % count
    }

    public func copyEntry() {
        guard let record = session.primarySelection else { return }
        copyEntries.copy(text: currentLoadedEntry?.rawText ?? session.text(of: record))
    }

    public func copyMessage() {
        guard let record = session.primarySelection else { return }
        let message = currentLoadedEntry?.details.message
            ?? LogEntryDetails.messageAndBody(session.text(of: record), record: record, profile: session.profile).message
        copyEntries.copy(text: message)
    }

    public func copyJSON() {
        guard let index = session.selectedRecords.last else { return }
        copyEntries.copyJSON(recordIndex: index, from: session)
    }

    public func openSource() {
        guard let record = session.primarySelection else { return }
        openSourceUseCase.open(record, profile: session.profile)
    }

    public func clearEntrySearch() {
        entrySearchText = ""
    }

    public func highlight(word: String) {
        entrySearchText = word
        currentMatch = 0
    }

    public func searchInLogTitle(for text: String) -> String {
        "Search for “\(SearchTitleText.shortened(text))” in Log"
    }

    public func searchInLog(text: String) {
        session.setSearchMode(.find)
        session.setSearchText(text)
    }

    public func isExpanded(_ id: String) -> Bool {
        expandedNodeIDs.contains(id)
    }

    public func toggleNode(id: String) {
        guard currentNodesByID[id]?.isContainer == true else { return }
        if expandedNodeIDs.remove(id) == nil {
            expandedNodeIDs.insert(id)
        }
    }

    public func visibleRows(of field: JSONFieldItem) -> [JSONTreeRowItem] {
        var rows: [JSONTreeRowItem] = []
        appendRows(of: field.tree, fieldID: field.id, depth: 0, to: &rows)
        return rows
    }

    public func copyValue(nodeID: String) {
        guard let node = currentNodesByID[nodeID] else { return }
        let text = node.isContainer ? JSONTreeBuilder.subtreeJSON(of: node) : JSONTreeBuilder.plainValue(of: node)
        copyEntries.copy(text: text)
    }

    public func copyKeyPath(nodeID: String) {
        guard let node = currentNodesByID[nodeID] else { return }
        copyEntries.copy(text: node.id)
    }

    public func copySubtree(nodeID: String) {
        guard let node = currentNodesByID[nodeID] else { return }
        copyEntries.copy(text: JSONTreeBuilder.subtreeJSON(of: node))
    }
}

// MARK: - Private

private extension EntryInspectorViewModel {

    var localMatchCount: Int { layout?.localMatches.count ?? 0 }

    var currentNodesByID: [String: JSONTreeNode] { currentLoadedEntry?.nodesByID ?? [:] }

    var currentLoadedEntry: LoadedEntry? {
        session.primarySelection.flatMap(loadedEntry(for:))
    }

    func loadedEntry(for record: LogRecord) -> LoadedEntry? {
        guard let loaded, loaded.offset == record.offset, loaded.length == record.length else { return nil }
        return loaded
    }

    func appendRows(of node: JSONTreeNode, fieldID: String, depth: Int, to rows: inout [JSONTreeRowItem]) {
        let rowID = Self.rowID(fieldID: fieldID, nodeID: node.id)
        let expanded = node.isContainer && expandedNodeIDs.contains(rowID)
        rows.append(JSONTreeRowItem(
            id: rowID,
            depth: depth,
            key: node.key,
            valueText: node.valueText,
            kind: node.kind,
            valueStyle: node.isContainer ? .preview : .fieldValue,
            isContainer: node.isContainer,
            isExpanded: expanded
        ))
        guard expanded else { return }
        for child in node.children {
            appendRows(of: child, fieldID: fieldID, depth: depth + 1, to: &rows)
        }
    }

    nonisolated static func makeLoadedEntry(record: LogRecord, rawText: String, profile: LogProfile) -> LoadedEntry {
        let details = LogEntryDetails.parse(rawText, record: record, profile: profile)
        var fields: [JSONFieldItem] = []
        var nodesByID: [String: JSONTreeNode] = [:]
        for (index, field) in details.fields.enumerated() {
            guard let tree = JSONTreeBuilder.build(field.prettyValue ?? field.value, limit: jsonNodeLimit) else { continue }
            let key = field.key.isEmpty ? "text" : field.key
            let item = JSONFieldItem(id: "\(index):\(key)", key: key, tree: tree)
            fields.append(item)
            collectNodes(tree, fieldID: item.id, into: &nodesByID)
        }
        return LoadedEntry(
            offset: record.offset,
            length: record.length,
            rawText: rawText,
            details: details,
            jsonFields: fields,
            nodesByID: nodesByID
        )
    }

    nonisolated static func collectNodes(_ node: JSONTreeNode, fieldID: String, into nodes: inout [String: JSONTreeNode]) {
        nodes[rowID(fieldID: fieldID, nodeID: node.id)] = node
        for child in node.children {
            collectNodes(child, fieldID: fieldID, into: &nodes)
        }
    }

    nonisolated static func defaultExpandedIDs(of fields: [JSONFieldItem]) -> Set<String> {
        var ids: Set<String> = []
        for field in fields {
            ids.insert(rowID(fieldID: field.id, nodeID: field.tree.id))
            for child in field.tree.children where child.isContainer {
                ids.insert(rowID(fieldID: field.id, nodeID: child.id))
            }
        }
        return ids
    }

    nonisolated static func rowID(fieldID: String, nodeID: String) -> String {
        fieldID + "/" + nodeID
    }
}
