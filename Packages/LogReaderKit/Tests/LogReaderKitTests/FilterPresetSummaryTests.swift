import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct FilterPresetSummaryTests {

    @Test func searchTextWithoutFacets() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchText = "payment"
        state.searchMode = .find

        #expect(FilterPresetSummary.text(of: state, profile: ProfileFixtures.textTrailing) == "Find: payment")
    }

    @Test func presetSummaryListsExtraTerms() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchText = "payment"
        state.extraTerms = [
            SearchTerm(text: "failed", isNegated: false),
            SearchTerm(text: "", isNegated: false),
            SearchTerm(text: "retry", isNegated: true)
        ]

        #expect(FilterPresetSummary.text(of: state, profile: ProfileFixtures.textTrailing) == "Filter: payment · and: failed · not: retry")
    }

    @Test func presetSummaryWithOnlyExtraTerms() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.extraTerms = [SearchTerm(text: "retry", isNegated: true)]

        #expect(FilterPresetSummary.text(of: state, profile: ProfileFixtures.textTrailing) == "not: retry")
    }

    @Test func facetsComeBeforeTheSearchText() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchText = "payment"
        state.facets[.level] = .only(["error"])
        state.facets[.attribute("tags")] = .only(["network"])

        #expect(FilterPresetSummary.text(of: state, profile: ProfileFixtures.textTrailing) == "ERR · #network · Filter: payment")
    }
}
