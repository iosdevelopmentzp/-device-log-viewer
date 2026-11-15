import Foundation

@MainActor
public enum StatusBarItemBuilder {

    public static func item(for session: LogSession, isExporting: Bool) -> StatusBarItem {
        StatusBarItem(
            kind: kind(for: session.status),
            entriesText: entriesText(for: session),
            sizeText: FileSizeText.file(Int64(session.content.totalBytes)),
            isFiltering: session.isFiltering,
            isExporting: isExporting,
            isFollowing: session.isFollowing,
            jumpTitle: session.newEntriesWhileDetached > 0 ? "\(session.newEntriesWhileDetached) new" : "Jump to End"
        )
    }
}

// MARK: - Private

private extension StatusBarItemBuilder {

    static func kind(for status: LogSessionStatus) -> StatusBarItem.Kind {
        switch status {
        case .loading: .loading
        case .live: .live
        case .missing: .missing
        }
    }

    static func entriesText(for session: LogSession) -> String {
        let total = session.content.records.count
        let visible = session.visible.count
        var text = visible == total ? "\(total) entries" : "\(visible) of \(total) entries"
        let state = session.filterState
        if state.searchMode == .find, state.searchText.isEmpty == false {
            text += " · \(session.findMatches.count) matches"
        }
        return text
    }
}
