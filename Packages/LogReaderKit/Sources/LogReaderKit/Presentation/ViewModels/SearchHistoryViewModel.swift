import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SearchHistoryViewModel {

    public var filterText = ""
    public var selectedID: UUID?

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings

    public var items: [RecentSearchItem] {
        let now = Date()
        let query = filterText.trimmingCharacters(in: .whitespaces)
        return settings.searchHistory.entries
            .filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
            .map { item(for: $0, now: now) }
    }

    public var isEmpty: Bool { settings.searchHistory.entries.isEmpty }

    public init(session: LogSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
    }

    public func apply(id: UUID) {
        guard var entry = settings.searchHistory.entry(id: id) else { return }
        session.setSearchMode(entry.mode)
        session.setSearchScope(entry.scope)
        session.setRegex(entry.isRegex)
        session.setSearchText(entry.text)
        settings.searchScope = session.filterState.searchScope
        settings.searchUsesRegex = session.filterState.isRegex
        entry.date = Date()
        settings.searchHistory = settings.searchHistory.adding(entry)
    }

    public func applySelected() {
        guard let id = selectedID ?? items.first?.id else { return }
        apply(id: id)
    }

    public func remove(id: UUID) {
        settings.searchHistory = settings.searchHistory.removing(id: id)
        guard selectedID == id else { return }
        selectedID = nil
    }

    public func togglePin(id: UUID) {
        settings.searchHistory = settings.searchHistory.togglingPin(id: id)
    }

    public func clear() {
        settings.searchHistory = settings.searchHistory.clearingUnpinned()
        guard let selectedID, settings.searchHistory.entry(id: selectedID) == nil else { return }
        self.selectedID = nil
    }
}

// MARK: - Private

private extension SearchHistoryViewModel {

    func item(for entry: RecentSearch, now: Date) -> RecentSearchItem {
        RecentSearchItem(
            id: entry.id,
            text: entry.text,
            modeTitle: entry.mode.displayName,
            scopeTitle: entry.scope.summary(in: session.profile),
            isRegexTitle: entry.isRegex ? "regex" : "",
            timeText: RelativeTimeText.text(for: entry.date, relativeTo: now),
            isPinned: entry.isPinned,
            pinSymbolName: entry.isPinned ? "pin.fill" : "pin"
        )
    }
}
