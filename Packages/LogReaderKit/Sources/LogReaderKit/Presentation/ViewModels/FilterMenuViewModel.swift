import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class FilterMenuViewModel {

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings

    public var levelOptions: [LevelOption] {
        let levels = session.filterState.facets.levels
        return session.profile.levels.map { LevelOption(id: $0.id, title: $0.title, style: $0.style, isOn: levels.isSelected($0.id)) }
    }

    public var isAllLevels: Bool { session.filterState.facets.levels.isAll }

    public var alertLevelsTitle: String? {
        let titles = session.profile.levels.filter(\.alerts).map(\.title)
        guard titles.isEmpty == false else { return nil }
        return titles.joined(separator: " and ") + " Only"
    }

    public var highlightedLevelsTitle: String? {
        guard let first = session.profile.levels.first(where: \.highlightsRow) else { return nil }
        return "\(first.title) and Above"
    }

    public var bookmarksOnly: Bool {
        get { session.filterState.bookmarksOnly }
        set { session.setBookmarksOnly(newValue) }
    }

    public var hasActiveFilters: Bool { session.filterState.hasActiveFilters }

    public var symbolName: String {
        hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }

    public var recentFilterItems: [RecentFilterItem] {
        settings.filterHistory.entries.prefix(FilterHistory.limit).map { entry in
            RecentFilterItem(
                id: entry.id,
                title: FilterSetSummary.text(facets: entry.facets, bookmarksOnly: entry.bookmarksOnly, profile: session.profile)
            )
        }
    }

    public var hasRecentFilters: Bool { settings.filterHistory.entries.isEmpty == false }

    public var hasTimeRange: Bool { session.hasTimeRange }

    public var hasClearedEntries: Bool { session.hasClearedEntries }

    public var canClearAroundSelection: Bool { session.selectedRecords.count == 1 }

    public var canClearSelection: Bool { session.selectedRecords.isEmpty == false }

    public init(session: LogSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
    }

    public func applyRecentFilter(id: UUID) {
        guard let entry = settings.filterHistory.entry(id: id) else { return }
        session.applyFacets(entry.facets, bookmarksOnly: entry.bookmarksOnly)
    }

    public func toggle(levelID: String) {
        session.toggleFacetValue(levelID, in: .level)
    }

    public func showAlertLevels() {
        let ids = Set(session.profile.levels.filter(\.alerts).map(\.id))
        guard ids.isEmpty == false else { return }
        session.setLevels(.only(ids))
    }

    public func showHighlightedAndAbove() {
        let levels = session.profile.levels
        guard let first = levels.firstIndex(where: \.highlightsRow) else { return }
        session.setLevels(.only(Set(levels[first...].map(\.id))))
    }

    public func showAllLevels() {
        session.setLevels(.all)
    }

    public func clearFilters() {
        session.clearFilters()
    }

    public func clearTimeRange() {
        session.clearTimeRange()
    }

    public func clearAllEntries() {
        session.clearAllEntries()
    }

    public func clearEntriesBeforeSelection() {
        session.clearEntriesBeforeSelection()
    }

    public func clearEntriesAfterSelection() {
        session.clearEntriesAfterSelection()
    }

    public func clearSelectedEntries() {
        session.clearSelectedEntries()
    }

    public func restoreAllEntries() {
        session.restoreAllEntries()
    }
}
