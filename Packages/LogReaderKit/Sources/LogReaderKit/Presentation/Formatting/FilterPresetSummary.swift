import Foundation
import LogReaderCore

public enum FilterPresetSummary {

    private static let separator = " · "

    public static func text(of state: LogFilterState, profile: LogProfile) -> String {
        let terms = state.activeExtraTerms.map(termText)
        guard terms.isEmpty == false else { return baseText(of: state, profile: profile) }
        let hasBase = state.searchText.isEmpty == false || state.facets.isAll == false || state.bookmarksOnly
        guard hasBase else { return terms.joined(separator: separator) }
        return ([baseText(of: state, profile: profile)] + terms).joined(separator: separator)
    }
}

// MARK: - Private

private extension FilterPresetSummary {

    static func baseText(of state: LogFilterState, profile: LogProfile) -> String {
        let facetsText = FilterSetSummary.text(facets: state.facets, bookmarksOnly: state.bookmarksOnly, profile: profile)
        guard state.searchText.isEmpty == false else { return facetsText }
        let searchText = "\(state.searchMode.displayName): \(state.searchText)"
        guard state.facets.isAll == false || state.bookmarksOnly else { return searchText }
        return facetsText + separator + searchText
    }

    static func termText(_ term: SearchTerm) -> String {
        (term.isNegated ? "not: " : "and: ") + term.text
    }
}
