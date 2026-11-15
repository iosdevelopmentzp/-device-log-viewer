import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class FilterChipsViewModel {

    @ObservationIgnored private let session: LogSession
    @ObservationIgnored private let settings: AppSettings

    private static let maxShownValues = 3

    public var chips: [FilterChipItem] {
        let state = session.filterState
        let facetChips = FacetColumn.all(in: session.profile)
            .filter { $0 != .level }
            .compactMap { facetChip(for: $0, in: state.facets) }
        return [searchChip(for: state), levelsChip(for: state.facets.levels)].compactMap { $0 }
            + facetChips
            + [bookmarksChip(for: state), timeRangeChip(for: state)].compactMap { $0 }
    }

    public var isEmpty: Bool { chips.isEmpty }

    public init(session: LogSession, settings: AppSettings) {
        self.session = session
        self.settings = settings
    }

    public func remove(_ chip: FilterChipItem) {
        switch chip.kind {
        case .search: session.setSearchText("")
        case .levels: session.setLevels(.all)
        case .facet(let column): session.showAll(in: column)
        case .bookmarks: session.setBookmarksOnly(false)
        case .timeRange: session.clearTimeRange()
        }
    }

    public func clearAll() {
        session.clearFilters()
    }
}

// MARK: - Private

private extension FilterChipsViewModel {

    func searchChip(for state: LogFilterState) -> FilterChipItem? {
        guard state.searchText.isEmpty == false else { return nil }
        let title = switch state.searchMode {
        case .filter: "\(state.searchMode.displayName): \(state.searchText)"
        case .find: "\(state.searchMode.displayName): \(state.searchText) (\(Self.matchesText(session.findMatches.count)))"
        }
        return FilterChipItem(id: "search", title: title, kind: .search, isExclusion: false)
    }

    func levelsChip(for levels: FacetFilter<String>) -> FilterChipItem? {
        guard levels.isAll == false else { return nil }
        let profile = session.profile
        let codes = profile.levels.filter { levels.values.contains($0.id) }.map(\.code)
            + levels.values.filter { profile.level(id: $0) == nil }.sorted()
        let title = Self.title(name: FacetColumn.level.columnTitle(in: profile), values: codes, isExclusion: levels.isExcluding)
        return FilterChipItem(id: "levels", title: title, kind: .levels, isExclusion: levels.isExcluding)
    }

    func facetChip(for column: FacetColumn, in facets: FacetSelection) -> FilterChipItem? {
        guard facets.isActive(column) else { return nil }
        let isExclusion = facets.isExcluding(column)
        let prefix = column.valuePrefix(in: session.profile)
        let values = facets.values(in: column).sorted().map { prefix + $0 }
        let title = Self.title(name: column.columnTitle(in: session.profile), values: values, isExclusion: isExclusion)
        return FilterChipItem(id: "facet.\(column.rawValue)", title: title, kind: .facet(column), isExclusion: isExclusion)
    }

    func bookmarksChip(for state: LogFilterState) -> FilterChipItem? {
        guard state.bookmarksOnly else { return nil }
        return FilterChipItem(id: "bookmarks", title: "Bookmarks only", kind: .bookmarks, isExclusion: false)
    }

    func timeRangeChip(for state: LogFilterState) -> FilterChipItem? {
        guard let range = state.timeRange else { return nil }
        let rangeText = TimeTextFormatter(timeZoneMode: settings.timeZoneMode).rangeText(range)
        return FilterChipItem(id: "timeRange", title: "Time: \(rangeText)", kind: .timeRange, isExclusion: false)
    }

    static func title(name: String, values: [String], isExclusion: Bool) -> String {
        let label = isExclusion ? "Not \(name.lowercased())" : name
        let shown = values.prefix(maxShownValues).joined(separator: ", ")
        let hiddenCount = values.count - maxShownValues
        guard hiddenCount > 0 else { return "\(label): \(shown)" }
        return "\(label): \(shown) +\(hiddenCount)"
    }

    static func matchesText(_ count: Int) -> String {
        switch count {
        case 0: "no matches"
        case 1: "1 match"
        default: "\(count) matches"
        }
    }
}
