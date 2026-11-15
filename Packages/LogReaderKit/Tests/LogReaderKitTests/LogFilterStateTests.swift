import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct LogFilterStateTests {

    @Test func newStateIsPassThrough() {
        let state = LogFilterState(searchScope: SearchScope(ids: ["message", "tags"]), isRegex: false)

        #expect(state.hasActiveFilters == false)
        #expect(state.findQuery == nil)
        #expect(state.makeFilter(bookmarks: [1]) == LogFilter(text: "", isRegex: false, scope: SearchScope(ids: ["message", "tags"]), facets: .all, onlyOffsets: nil, timeRange: nil, startIndex: nil, hiddenRange: nil, hiddenOffsets: nil, extraTerms: []))
    }

    @Test func clearedEntriesAndTimeRangeAreNotPresetContent() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.markIndex = 10
        state.clearedAfterRange = 20..<30
        state.clearedOffsets = [5]
        state.timeRange = 1...2

        #expect(state.hasActiveFilters)
        #expect(state.hasPresetContent == false)

        state.bookmarksOnly = true

        #expect(state.hasPresetContent)
    }

    @Test func filterModeUsesTextInTheFilter() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchText = "socket"

        #expect(state.makeFilter(bookmarks: []).text == "socket")
        #expect(state.findQuery == nil)
        #expect(state.hasActiveFilters)
    }

    @Test func findModeUsesTextOnlyInTheQuery() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchMode = .find
        state.searchText = "socket"

        #expect(state.makeFilter(bookmarks: []).text.isEmpty)
        #expect(state.findQuery?.text == "socket")
        #expect(state.hasActiveFilters)
    }

    @Test func regexStateBuildsRegexQueries() throws {
        var state = LogFilterState(searchScope: .message, isRegex: true)
        state.searchMode = .find
        state.searchText = "user/\\d+"

        let query = try #require(state.findQuery)
        #expect(query.isRegex)
        #expect(query.matches("user/42"))
        #expect(state.highlightQuery == query)
        #expect(state.makeFilter(bookmarks: []).isRegex)
    }

    @Test func invalidRegexGivesNoQuery() {
        var state = LogFilterState(searchScope: .message, isRegex: true)
        state.searchMode = .find
        state.searchText = "user("

        #expect(state.findQuery == nil)
        #expect(state.highlightQuery == nil)
    }

    @Test func emptyTextGivesNoHighlightQuery() {
        let state = LogFilterState(searchScope: .message, isRegex: true)

        #expect(state.highlightQuery == nil)
    }

    @Test func bookmarksOnlyLimitsOffsets() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.bookmarksOnly = true

        #expect(state.makeFilter(bookmarks: [4, 8]).onlyOffsets == [4, 8])
        #expect(state.hasActiveFilters)
    }

    @Test func facetSelectionMakesFiltersActive() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.facets.toggle("error", in: .level)

        #expect(state.hasActiveFilters)
        #expect(state.makeFilter(bookmarks: []).facets.levels == .only(["error"]))
    }

    @Test func clearedEntriesGoIntoTheFilter() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        #expect(state.hasClearedEntries == false)

        state.markIndex = 2
        state.clearedAfterRange = 8..<12
        state.clearedOffsets = [40]
        let filter = state.makeFilter(bookmarks: [])

        #expect(state.hasClearedEntries)
        #expect(state.hasActiveFilters)
        #expect(filter.startIndex == 2)
        #expect(filter.hiddenRange == 8..<12)
        #expect(filter.hiddenOffsets == [40])

        state.restoreAllEntries()

        #expect(state.hasClearedEntries == false)
        #expect(state.makeFilter(bookmarks: []).hiddenOffsets == nil)
    }

    @Test func applyPresetKeepsClearedEntries() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.markIndex = 2
        state.clearedAfterRange = 8..<12
        state.clearedOffsets = [40]
        state.timeRange = 1...2
        state.searchText = "error"
        let preset = state.makePreset(name: "Errors")
        state.searchText = ""

        state.apply(preset)

        #expect(state.searchText == "error")
        #expect(state.timeRange == nil)
        #expect(state.markIndex == 2)
        #expect(state.clearedAfterRange == 8..<12)
        #expect(state.clearedOffsets == [40])
    }

    @Test func clearRemovesClearedEntries() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.markIndex = 2
        state.clearedAfterRange = 8..<12
        state.clearedOffsets = [40]

        state.clear()

        #expect(state.hasClearedEntries == false)
    }

    @Test func clearKeepsModeAndScope() {
        var state = LogFilterState(searchScope: SearchScope(ids: ["tags"]), isRegex: false)
        state.searchMode = .find
        state.searchText = "x"
        state.bookmarksOnly = true
        state.facets.toggle("error", in: .level)

        state.clear()

        #expect(state.searchText.isEmpty)
        #expect(state.bookmarksOnly == false)
        #expect(state.facets == .all)
        #expect(state.searchMode == .find)
        #expect(state.searchScope == SearchScope(ids: ["tags"]))
    }

    @Test func extraTermsAreActiveFiltersOnlyWithText() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.extraTerms = [SearchTerm(text: "", isNegated: false)]

        #expect(state.hasActiveFilters == false)
        #expect(state.hasPresetContent == false)
        #expect(state.makeFilter(bookmarks: []).extraTerms.isEmpty)

        state.extraTerms.append(SearchTerm(text: "timeout", isNegated: true))

        #expect(state.hasActiveFilters)
        #expect(state.hasPresetContent)
        #expect(state.makeFilter(bookmarks: []).extraTerms == [SearchTerm(text: "timeout", isNegated: true)])
        #expect(state.findTerms.isEmpty)
    }

    @Test func findModeMovesExtraTermsOutOfTheFilter() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchMode = .find
        state.extraTerms = [SearchTerm(text: "socket", isNegated: false)]

        #expect(state.makeFilter(bookmarks: []).extraTerms.isEmpty)
        #expect(state.findTerms == [SearchTerm(text: "socket", isNegated: false)])
        #expect(state.hasActiveFilters)
    }

    @Test func highlightQueriesHoldTheMainTextAndPositiveTerms() {
        var state = LogFilterState(searchScope: .message, isRegex: true)
        state.searchText = "user/\\d+"
        state.extraTerms = [
            SearchTerm(text: "socket", isNegated: false),
            SearchTerm(text: "noise", isNegated: true),
            SearchTerm(text: "(", isNegated: false),
            SearchTerm(text: "", isNegated: false)
        ]

        #expect(state.highlightQueries.map(\.text) == ["user/\\d+", "socket"])
        #expect(state.highlightQueries.first == state.highlightQuery)
    }

    @Test func clearRemovesExtraTerms() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.extraTerms = [SearchTerm(text: "socket", isNegated: false)]

        state.clear()

        #expect(state.extraTerms.isEmpty)
    }

    @Test func atMostThreeExtraTermsCanBeAdded() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.extraTerms = Array(repeating: SearchTerm(text: "", isNegated: false), count: 2)

        #expect(state.canAddExtraTerm)

        state.extraTerms.append(SearchTerm(text: "", isNegated: false))

        #expect(state.canAddExtraTerm == false)
    }
}
