import Foundation
import LogReaderCore

@MainActor
public enum RowContextMenuModel {

    private static let lineJoiner = " ⏎ "

    public static func entries(
        session: LogSession,
        recordIndices: [Int],
        copyEntries: CopyEntries,
        openSource: OpenSource,
        settings: AppSettings,
        showDetails: @escaping @MainActor () -> Void
    ) -> [ContextMenuEntry] {
        guard let recordIndex = recordIndices.last, let record = session.record(at: recordIndex) else { return [] }
        let profile = session.profile
        let suffix = recordIndices.count > 1 ? " (\(recordIndices.count))" : ""
        let hasActiveFilters = session.filterState.hasActiveFilters
        var entries = copyItems(
            session: session,
            record: record,
            recordIndex: recordIndex,
            recordIndices: recordIndices,
            copyEntries: copyEntries,
            suffix: suffix
        )
        entries.append(.separator)
        let isBookmarked = recordIndices.allSatisfy { index in
            session.record(at: index).map(session.isBookmarked) ?? false
        }
        entries.append(item((isBookmarked ? "Remove Bookmark" : "Add Bookmark") + suffix) {
            session.toggleBookmarks(recordIndices: recordIndices)
        })
        entries.append(item("Show Details", action: showDetails))
        if profile.sourceReference(of: record) != nil {
            entries.append(item(profile.source.openTitle) { openSource.open(record, profile: profile) })
        }
        if hasActiveFilters {
            entries.append(item("Show in Full Log") { session.showInFullLog(recordIndex: recordIndex) })
        }
        entries += timeRangeItems(session: session, record: record, recordIndices: recordIndices)
        entries.append(.separator)
        entries += clearItems(session: session, recordIndex: recordIndex, recordIndices: recordIndices, suffix: suffix)
        entries.append(.separator)
        entries += filterItems(session: session, record: record, profile: profile, settings: settings)
        if hasActiveFilters {
            entries.append(.separator)
            entries.append(item("Clear Filters") { session.clearFilters() })
        }
        return entries
    }
}

// MARK: - Private

private extension RowContextMenuModel {

    static func item(_ title: String, action: @escaping @MainActor () -> Void) -> ContextMenuEntry {
        .item(ContextMenuItem(title: title, isEnabled: true, action: action))
    }

    static func copyItems(
        session: LogSession,
        record: LogRecord,
        recordIndex: Int,
        recordIndices: [Int],
        copyEntries: CopyEntries,
        suffix: String
    ) -> [ContextMenuEntry] {
        var entries = [ContextMenuEntry]()
        entries.append(item("Copy Entry" + suffix) {
            copyEntries.copy(recordIndices: recordIndices, from: session)
        })
        entries.append(item("Copy Message") {
            let parts = LogEntryDetails.messageAndBody(session.text(of: record), record: record, profile: session.profile)
            copyEntries.copy(text: parts.message)
        })
        entries.append(item("Copy as JSON") {
            copyEntries.copyJSON(recordIndex: recordIndex, from: session)
        })
        if let source = session.profile.source(of: record), let title = session.profile.attributes.first(where: { $0.role == .source })?.title {
            entries.append(item("Copy \(title) “\(source)”") { copyEntries.copy(text: source) })
        }
        return entries
    }

    static func filterItems(session: LogSession, record: LogRecord, profile: LogProfile, settings: AppSettings) -> [ContextMenuEntry] {
        var entries = [ContextMenuEntry]()
        if let level = record.level.flatMap(profile.rule(of:)) {
            entries.append(item("Show Only Level \(level.title)") { session.showOnly([level.id], in: .level) })
        }
        for (attribute, value) in facetValues(of: record, profile: profile) {
            entries.append(item("Show Only \(attribute.title) \(quoted(value, attribute: attribute))") {
                session.showOnly([value], in: .attribute(attribute.id))
            })
        }
        let hideItems = hideItems(session: session, record: record, profile: profile)
        if hideItems.isEmpty == false {
            entries.append(.separator)
            entries += hideItems
        }
        let message = record.message.components(separatedBy: lineJoiner).first ?? record.message
        if message.isEmpty == false {
            entries.append(item("Search for “\(SearchTitleText.shortened(message))”") {
                var scope = session.filterState.searchScope
                scope.insert(SearchScope.messageID)
                session.setSearchScope(scope)
                settings.searchScope = session.filterState.searchScope
                session.setSearchText(message)
            })
        }
        return entries
    }

    static func timeRangeItems(session: LogSession, record: LogRecord, recordIndices: [Int]) -> [ContextMenuEntry] {
        var entries = [ContextMenuEntry]()
        if let timestamp = record.timestamp {
            entries.append(item("Show Only From This Entry") {
                session.setTimeRange(timestamp...Double.greatestFiniteMagnitude)
            })
        }
        let timestamps = recordIndices.compactMap { session.record(at: $0)?.timestamp }
        if timestamps.count > 1, let lower = timestamps.min(), let upper = timestamps.max() {
            entries.append(item("Show Only Between Selected Entries") { session.setTimeRange(lower...upper) })
        }
        return entries
    }

    static func clearItems(session: LogSession, recordIndex: Int, recordIndices: [Int], suffix: String) -> [ContextMenuEntry] {
        var entries = [ContextMenuEntry]()
        entries.append(item("Clear Entries Before This") { session.clearEntries(before: recordIndex) })
        entries.append(item("Clear Entries After This") { session.clearEntries(after: recordIndex) })
        entries.append(item("Clear Selected Entries" + suffix) { session.clearEntries(recordIndices: recordIndices) })
        if session.hasClearedEntries {
            entries.append(item("Restore All Entries") { session.restoreAllEntries() })
        }
        return entries
    }

    static func hideItems(session: LogSession, record: LogRecord, profile: LogProfile) -> [ContextMenuEntry] {
        var entries = [ContextMenuEntry]()
        if let level = record.level.flatMap(profile.rule(of:)) {
            entries.append(item("Hide Level \(level.title)") { session.exclude([level.id], in: .level) })
        }
        for (attribute, value) in facetValues(of: record, profile: profile) {
            entries.append(item("Hide \(attribute.title) \(quoted(value, attribute: attribute))") {
                session.exclude([value], in: .attribute(attribute.id))
            })
        }
        return entries
    }

    static func facetValues(of record: LogRecord, profile: LogProfile) -> [(AttributeRule, String)] {
        profile.attributes.enumerated().flatMap { index, attribute -> [(AttributeRule, String)] in
            guard attribute.facet else { return [] }
            return attribute.facetValues(of: profile.value(of: record, attribute: index)).map { (attribute, $0) }
        }
    }

    static func quoted(_ value: String, attribute: AttributeRule) -> String {
        attribute.kind == .list ? attribute.prefix + value : "“\(value)”"
    }
}
