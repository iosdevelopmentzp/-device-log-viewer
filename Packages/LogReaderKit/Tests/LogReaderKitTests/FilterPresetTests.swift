import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct FilterPresetTests {

    @Test func presetRoundTripsThroughTheFilterState() {
        var state = LogFilterState(searchScope: SearchScope(ids: ["message", "tags"]), isRegex: false)
        state.searchText = "socket"
        state.searchMode = .find
        state.facets[.level] = .only(["error"])
        state.facets[.attribute("source")] = .except(["Store"])
        state.bookmarksOnly = true

        let preset = state.makePreset(name: "Errors")

        #expect(preset.name == "Errors")
        #expect(LogFilterState(preset: preset) == state)
    }

    @Test func presetKeepsTheRegexFlag() throws {
        var state = LogFilterState(searchScope: .message, isRegex: true)
        state.searchText = "fail(ed)?"

        let preset = state.makePreset(name: "Regex")
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(FilterPreset.self, from: data)

        #expect(preset.isRegex)
        #expect(decoded.isRegex)
        #expect(LogFilterState(preset: decoded) == state)
    }

    @Test func storedPresetWithoutRegexFieldDecodesAsPlain() throws {
        let preset = LogFilterState(searchScope: .message, isRegex: false).makePreset(name: "Old")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(preset)) as? [String: Any])
        object["isRegex"] = nil
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(FilterPreset.self, from: data)

        #expect(decoded.isRegex == false)
        #expect(decoded == preset)
    }

    @Test func everyPresetGetsANewID() {
        let state = LogFilterState(searchScope: .message, isRegex: false)

        #expect(state.makePreset(name: "A").id != state.makePreset(name: "A").id)
    }

    @Test func presetRoundTripsThroughJSON() throws {
        var state = LogFilterState(searchScope: SearchScope(ids: ["message", "source"]), isRegex: false)
        state.searchText = "timeout"
        state.facets[.attribute("tags")] = .only(["network"])
        let preset = state.makePreset(name: "Network")

        let data = try JSONEncoder().encode(preset)

        #expect(try JSONDecoder().decode(FilterPreset.self, from: data) == preset)
    }

    @Test func presetKeepsTheActiveExtraTerms() throws {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.searchText = "payment"
        state.extraTerms = [SearchTerm(text: "failed", isNegated: false), SearchTerm(text: "retry", isNegated: true)]

        let preset = state.makePreset(name: "Terms")
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(FilterPreset.self, from: data)

        #expect(decoded.extraTerms == state.extraTerms)
        #expect(LogFilterState(preset: decoded) == state)
    }

    @Test func presetDropsEmptyExtraTerms() {
        var state = LogFilterState(searchScope: .message, isRegex: false)
        state.extraTerms = [SearchTerm(text: "", isNegated: false), SearchTerm(text: "retry", isNegated: true)]

        #expect(state.makePreset(name: "Terms").extraTerms == [SearchTerm(text: "retry", isNegated: true)])
    }

    @Test func storedPresetWithoutExtraTermsDecodesAsEmpty() throws {
        let preset = LogFilterState(searchScope: .message, isRegex: false).makePreset(name: "Old")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(preset)) as? [String: Any])
        object["extraTerms"] = nil
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(FilterPreset.self, from: data)

        #expect(decoded.extraTerms.isEmpty)
        #expect(decoded == preset)
    }

    @Test func storedPresetWithTheLegacySearchScopeAndLevelsDecodes() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Old","searchText":"x","searchMode":"filter",\
        "searchScope":3,"facets":{"levels":{"only":{"_0":[3]}},"columns":{"tags":{"only":{"_0":["network"]}}}},"bookmarksOnly":false}
        """

        let decoded = try JSONDecoder().decode(FilterPreset.self, from: Data(json.utf8))

        #expect(decoded.searchScope == SearchScope(ids: ["message", "tags"]))
        #expect(decoded.facets.levels == .only(["warning"]))
        #expect(decoded.facets[.attribute("tags")] == .only(["network"]))
        #expect(decoded.extraTerms.isEmpty)
    }
}
