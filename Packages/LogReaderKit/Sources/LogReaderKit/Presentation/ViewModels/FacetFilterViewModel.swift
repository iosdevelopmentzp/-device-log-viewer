import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class FacetFilterViewModel {

    public let column: FacetColumn

    @ObservationIgnored private let session: LogSession
    private var modeWhileEmpty = FacetMode.include

    public var title: String { column.displayName(in: session.profile) }

    public var mode: FacetMode {
        get { isActive ? session.filterState.facets.mode(of: column) : modeWhileEmpty }
        set {
            modeWhileEmpty = newValue
            session.setFacetMode(newValue, in: column)
        }
    }

    public var modeOptions: [FacetModeOption] {
        FacetMode.allCases.map { FacetModeOption(mode: $0, title: $0.displayName) }
    }

    public var hint: String {
        switch (mode, isActive) {
        case (.include, true): "Only the checked values are shown."
        case (.include, false): "Nothing is checked, so every entry is shown. Check values to show only them."
        case (.exclude, true): "The checked values are hidden."
        case (.exclude, false): "Nothing is checked, so every entry is shown. Check values to hide them."
        }
    }

    public var isActive: Bool { session.filterState.facets.isActive(column) }

    public var hasValues: Bool { entries.isEmpty == false }

    public var showsSearchField: Bool { entries.count > Self.searchThreshold }

    public var searchPrompt: String { "Search \(column.displayName(in: session.profile).lowercased())" }

    private static let searchThreshold = 8

    public init(session: LogSession, column: FacetColumn) {
        self.session = session
        self.column = column
    }

    public func values(matching query: String) -> [FacetValueItem] {
        let facets = session.filterState.facets
        let mode = mode
        let profile = session.profile
        let prefix = column.valuePrefix(in: profile)
        return entries
            .filter { query.isEmpty || title(of: $0.value, prefix: prefix, profile: profile).localizedCaseInsensitiveContains(query) }
            .map { entry in
                FacetValueItem(
                    value: entry.value,
                    title: title(of: entry.value, prefix: prefix, profile: profile),
                    count: entry.count,
                    countText: "\(entry.count)",
                    isSelected: facets.isSelected(entry.value, in: column),
                    actionTitle: mode == .include ? "Only" : "Hide",
                    actionHelp: mode == .include ? "Show only entries with this value" : "Hide only entries with this value"
                )
            }
    }

    public func toggle(_ item: FacetValueItem) {
        modeWhileEmpty = mode
        if mode == .exclude && isActive == false {
            session.hideOnly([item.value], in: column)
        } else {
            session.toggleFacetValue(item.value, in: column)
        }
    }

    public func only(_ item: FacetValueItem) {
        modeWhileEmpty = mode
        switch mode {
        case .include: session.showOnly([item.value], in: column)
        case .exclude: session.hideOnly([item.value], in: column)
        }
    }

    public func clear() {
        modeWhileEmpty = mode
        session.showAll(in: column)
    }
}

// MARK: - Private

private extension FacetFilterViewModel {

    var entries: [FacetCounts.Entry] {
        session.facetCounts.entries(in: column)
    }

    func title(of value: String, prefix: String, profile: LogProfile) -> String {
        guard column.isLevel else { return prefix + value }
        return profile.level(id: value).flatMap(profile.rule(of:))?.title ?? value
    }
}
