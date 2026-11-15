import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SearchViewModel {

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings

    @ObservationIgnored public private(set) lazy var historyViewModel = SearchHistoryViewModel(session: session, settings: settings)

    public var text: String {
        get { session.filterState.searchText }
        set { session.setSearchText(newValue) }
    }

    public var mode: SearchMode {
        get { session.filterState.searchMode }
        set { session.setSearchMode(newValue) }
    }

    public var isRegex: Bool {
        get { session.filterState.isRegex }
        set {
            session.setRegex(newValue)
            settings.searchUsesRegex = newValue
        }
    }

    public var regexError: String? {
        let state = session.filterState
        guard state.isRegex, state.searchText.isEmpty == false else { return nil }
        do {
            _ = try TextQuery.regex(state.searchText)
            return nil
        } catch {
            return "Invalid expression: " + Self.firstLine(of: error.localizedDescription)
        }
    }

    public var isTextValid: Bool { regexError == nil }

    public var fieldHelp: String { regexError ?? "" }

    public var modeOptions: [SearchModeOption] {
        SearchMode.allCases.map { SearchModeOption(mode: $0, title: $0.displayName) }
    }

    public var scopeOptions: [SearchScopeOption] {
        let scope = session.filterState.searchScope
        let profile = session.profile
        return SearchScope.optionIDs(in: profile).map { id in
            SearchScopeOption(id: id, title: SearchScope.displayName(ofID: id, in: profile), isOn: scope.contains(id))
        }
    }

    public var isScopeDefault: Bool { session.filterState.searchScope == .message }

    public var scopeSummary: String {
        "Search in: \(session.filterState.searchScope.summary(in: session.profile))"
    }

    public var prompt: String { mode.prompt }

    public var showsFindControls: Bool {
        mode == .find && (text.isEmpty == false || session.filterState.activeExtraTerms.isEmpty == false)
    }

    public var showsClearButton: Bool { text.isEmpty == false }

    public var positionText: String {
        guard session.findMatches.isEmpty == false else { return "No matches" }
        let position = session.findPosition.map { "\($0 + 1)" } ?? "–"
        return "\(position)/\(session.findMatches.count)"
    }

    public var canNavigate: Bool { session.findMatches.isEmpty == false }

    public var canAddCondition: Bool { session.filterState.canAddExtraTerm }

    public var hasHistory: Bool { settings.searchHistory.entries.isEmpty == false }

    public init(session: LogSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
    }

    public func submit() {
        guard mode == .find else { return }
        findNext()
    }

    public func commitSearch() {
        let state = session.filterState
        guard state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
        let entry = RecentSearch(
            id: UUID(),
            text: state.searchText,
            mode: state.searchMode,
            scope: state.searchScope,
            isRegex: state.isRegex,
            date: Date(),
            isPinned: false
        )
        settings.searchHistory = settings.searchHistory.adding(entry)
    }

    public func addCondition() {
        session.addExtraTerm()
    }

    public func findNext() {
        session.findNext()
    }

    public func findPrevious() {
        session.findPrevious()
    }

    public func clear() {
        session.setSearchText("")
    }

    public func toggleScope(id: String) {
        session.toggleSearchScope(id)
        persistScope()
    }

    public func useMessageScope() {
        session.setSearchScope(.message)
        persistScope()
    }

    public func useAllScopes() {
        session.setSearchScope(SearchScope(ids: Set(SearchScope.optionIDs(in: session.profile))))
        persistScope()
    }
}

// MARK: - Private

private extension SearchViewModel {

    func persistScope() {
        settings.searchScope = session.filterState.searchScope
    }

    static func firstLine(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.trimmingCharacters(in: .whitespaces)
    }
}
