import Foundation
import Testing
@testable import LogReaderCore

struct LogFilterEngineTests {

    private let profile = ProfileFixtures.textTrailing
    private let tags = FacetColumn.attribute("tags")
    private let category = FacetColumn.attribute("category")
    private let source = FacetColumn.attribute("source")

    private func makeContent() throws -> LogContent {
        let text = ProfileFixtures.header
            + "Socket connected #network INF [websocket] [Sockets:10] 2026-10-07 22:18:54.000\n\u{1E}"
            + "Payment failed ERR [default] [Store:20] 2026-10-07 22:18:55.000\n  reason: Привет Мир\n\u{1E}"
            + "Debug noise DBG [default] [Misc:30] 2026-10-07 22:18:56.000\n\u{1E}"
        return try ProfileFixtures.content(text, profile: profile)
    }

    @Test func passThroughReturnsEverything() throws {
        let content = try makeContent()
        let result = try LogFilterEngine.indices(in: content, range: 0..<3, filter: .all)
        #expect(result == [0, 1, 2])
    }

    @Test func asciiSearchIsCaseInsensitiveAndScansFields() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.text = "SOCKET"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0])

        filter.text = "reason"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    @Test func searchScopeLimitsWhereTextIsSearched() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.text = "network"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter).isEmpty)

        filter.scope = SearchScope(ids: ["message", "tags"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0])

        filter.text = "Store:20"
        filter.scope = .message
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter).isEmpty)
        filter.scope = SearchScope(ids: ["source"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])

        filter.text = "error"
        filter.scope = SearchScope(ids: ["level"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    @Test func regexFilterFindsEntries() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.isRegex = true
        filter.text = "^(socket|debug)\\b"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 2])

        filter.text = "мир$"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    @Test func invalidRegexPassesTextThrough() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.isRegex = true
        filter.text = "socket("
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1, 2])
    }

    @Test func unicodeSearchFallsBackToStringMatching() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.text = "мир"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    @Test func levelTagCategoryAndOffsetFilters() throws {
        let content = try makeContent()

        var filter = LogFilter.all
        filter.facets[.level] = .only(["error", "fault"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])

        filter = .all
        filter.facets[tags] = .only(["network"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0])

        filter = .all
        filter.facets[category] = .only(["default"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1, 2])

        filter = .all
        filter.facets[source] = .only(["Store", "Misc"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1, 2])

        filter = .all
        filter.onlyOffsets = [content.records[2].offset]
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [2])
    }

    @Test func exceptFiltersHideOnlyTheExcludedValues() throws {
        let content = try makeContent()

        var filter = LogFilter.all
        filter.facets[tags] = .except(["network"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1, 2])

        filter = .all
        filter.facets[.level] = .except(["debug"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1])

        filter = .all
        filter.facets[category] = .except(["default"])
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0])

        filter = .all
        filter.facets[source] = .except(["Store"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 2])
    }

    @Test func exceptCategoryShowsEntriesWithoutCategory() throws {
        let text = ProfileFixtures.header
            + "No category INF [Misc:1] 2026-10-07 22:18:54.000\n\u{1E}"
            + "Has category INF [default] [Misc:2] 2026-10-07 22:18:55.000\n\u{1E}"
        let content = try ProfileFixtures.content(text, profile: profile)
        #expect(profile.value(of: content.records[0], attributeID: "category") == .none)

        var filter = LogFilter.all
        filter.facets[category] = .except(["default"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<2, filter: filter) == [0])
    }

    @Test func facetSelectionLevelIDsFilterRecords() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.facets.showOnly(["error", "debug"], in: .level)
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1, 2])
    }

    @Test func startIndexSkipsEarlierRecords() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.startIndex = 1
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1, 2])
        #expect(try LogFilterEngine.indices(in: content, range: 2..<3, filter: filter) == [2])

        filter.startIndex = 3
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter).isEmpty)
    }

    @Test func hiddenRangeHidesOnlyRecordsInside() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.hiddenRange = 1..<2
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 2])
        #expect(try LogFilterEngine.indices(in: content, range: 1..<2, filter: filter).isEmpty)
        #expect(try LogFilterEngine.indices(in: content, range: 2..<3, filter: filter) == [2])

        filter.startIndex = 1
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [2])

        filter.startIndex = nil
        filter.hiddenRange = 2..<2
        #expect(filter.isPassThrough)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1, 2])
    }

    @Test func hiddenOffsetsDropMatchingRecords() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.hiddenOffsets = [content.records[1].offset]
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 2])

        filter.hiddenOffsets = []
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1, 2])
    }

    @Test func timeRangeDropsRecordsOutsideAndWithoutTimestamps() throws {
        let text = ProfileFixtures.header
            + "First INF [Misc:1] 2026-10-07 22:18:54.000\n\u{1E}"
            + "Plain line without a header\n\u{1E}"
            + "Second INF [Misc:2] 2026-10-07 22:18:55.000\n\u{1E}"
            + "Third INF [Misc:3] 2026-10-07 22:18:56.000\n\u{1E}"
        let content = try ProfileFixtures.content(text, profile: profile)
        #expect(content.records[1].timestamp == nil)
        let first = try #require(content.records[0].timestamp)

        var filter = LogFilter.all
        filter.timeRange = (first + 0.5)...(first + 1.5)
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<4, filter: filter) == [2])

        filter.timeRange = first...Double.greatestFiniteMagnitude
        #expect(try LogFilterEngine.indices(in: content, range: 0..<4, filter: filter) == [0, 2, 3])
    }

    @Test func facetToggleMovesBetweenStates() {
        let filter = FacetFilter<String>.all.togglingSelection("a")
        #expect(filter == .only(["a"]))
        #expect(filter.isSelected("a"))
        #expect(filter.isSelected("b") == false)
        #expect(FacetFilter<String>.all.isSelected("a") == false)
        #expect(filter.togglingSelection("b") == .only(["a", "b"]))
        #expect(filter.togglingSelection("a") == .all)
    }

    @Test func textQueryRangesFindsEveryOccurrence() throws {
        let query = try #require(TextQuery("ab"))
        #expect(query.ranges(in: "xxABxxabx").count == 2)
    }

    @Test func extraTermsNarrowTheFilter() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.extraTerms = [SearchTerm(text: "failed", isNegated: false)]
        #expect(filter.isPassThrough == false)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])

        filter.text = "socket"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter).isEmpty)
    }

    @Test func negatedTermsExcludeEntries() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.extraTerms = [SearchTerm(text: "noise", isNegated: true)]
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1])

        filter.extraTerms.append(SearchTerm(text: "SOCKET", isNegated: true))
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    @Test func extraTermsUseTheFilterScope() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.extraTerms = [SearchTerm(text: "network", isNegated: false)]
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter).isEmpty)

        filter.scope = SearchScope(ids: ["message", "tags"])
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0])
    }

    @Test func emptyTermIsIgnored() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.extraTerms = [SearchTerm(text: "", isNegated: true)]
        #expect(filter.isPassThrough)
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1, 2])

        filter.text = "debug"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [2])
    }

    @Test func invalidRegexTermIsIgnored() throws {
        let content = try makeContent()
        var filter = LogFilter.all
        filter.isRegex = true
        filter.extraTerms = [SearchTerm(text: "(", isNegated: false), SearchTerm(text: "^debug", isNegated: true)]
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [0, 1])
    }

    @Test func textMatchesRespectsTerms() throws {
        let content = try makeContent()
        let candidates = [0, 1, 2]
        let positive = try LogFilterEngine.textMatches(
            in: content,
            candidates: candidates,
            query: TextQuery("e"),
            terms: [SearchTerm(text: "payment", isNegated: false)],
            isRegex: false,
            scope: .message
        )
        #expect(positive == [1])

        let negative = try LogFilterEngine.textMatches(
            in: content,
            candidates: candidates,
            query: nil,
            terms: [SearchTerm(text: "noise", isNegated: true), SearchTerm(text: "", isNegated: false)],
            isRegex: false,
            scope: .message
        )
        #expect(negative == [0, 1])
    }

    @Test func textMatchesWithoutQueriesFindsNothing() throws {
        let content = try makeContent()
        let result = try LogFilterEngine.textMatches(
            in: content,
            candidates: [0, 1, 2],
            query: nil,
            terms: [SearchTerm(text: "", isNegated: false), SearchTerm(text: "[", isNegated: true)],
            isRegex: true,
            scope: .message
        )
        #expect(result.isEmpty)
    }
}
