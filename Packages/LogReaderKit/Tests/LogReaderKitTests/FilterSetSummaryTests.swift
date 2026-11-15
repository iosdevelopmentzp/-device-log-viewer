import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct FilterSetSummaryTests {

    @Test func levelsTagsAndBookmarks() {
        var facets = FacetSelection.all
        facets[.level] = .only(["fault", "error"])
        facets[.attribute("tags")] = .only(["network"])

        let text = FilterSetSummary.text(facets: facets, bookmarksOnly: true, profile: ProfileFixtures.textTrailing)

        #expect(text == "ERR, FLT · #network · Bookmarks")
    }

    @Test func excludeModeAddsNot() {
        var facets = FacetSelection.all
        facets[.level] = .except(["debug"])
        facets[.attribute("category")] = .except(["default"])
        facets[.attribute("source")] = .only(["Store"])

        let text = FilterSetSummary.text(facets: facets, bookmarksOnly: false, profile: ProfileFixtures.textTrailing)

        #expect(text == "not DBG · not default · Store")
    }

    @Test func moreThanThreeValuesAreCounted() {
        var facets = FacetSelection.all
        facets[.attribute("tags")] = .only(["a", "b", "c", "d", "e"])

        let text = FilterSetSummary.text(facets: facets, bookmarksOnly: false, profile: ProfileFixtures.textTrailing)

        #expect(text == "#a, #b, #c +2")
    }

    @Test func noFiltersGivesAllEntries() {
        #expect(FilterSetSummary.text(facets: .all, bookmarksOnly: false, profile: ProfileFixtures.textTrailing) == "All entries")
    }

    @Test func unknownLevelIDsComeAfterTheProfileLevels() {
        var facets = FacetSelection.all
        facets[.level] = .only(["trace", "error"])

        #expect(FilterSetSummary.text(facets: facets, bookmarksOnly: false, profile: ProfileFixtures.textTrailing) == "ERR, trace")
    }

    @Test func attributesFollowTheBuiltInProfile() {
        var facets = FacetSelection.all
        facets[.level] = .only(["error"])
        facets[.attribute("subsystem")] = .only(["com.example"])

        #expect(FilterSetSummary.text(facets: facets, bookmarksOnly: false, profile: ProfileFixtures.jsonLines) == "error · com.example")
    }
}
