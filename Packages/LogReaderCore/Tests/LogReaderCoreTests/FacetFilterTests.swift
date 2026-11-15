import Testing
@testable import LogReaderCore

struct FacetFilterTests {

    @Test func exceptHidesTheValuesInTheSet() {
        let filter = FacetFilter<String>.except(["a"])
        #expect(filter.allows("a") == false)
        #expect(filter.allows("b"))
        #expect(filter.isAll == false)
        #expect(filter.isExcluding)
        #expect(FacetFilter<String>.only(["a"]).isExcluding == false)
        #expect(FacetFilter<String>.all.isExcluding == false)
    }

    @Test func exceptAllowsAMissingValue() {
        #expect(FacetFilter<String>.except(["a"]).allows(nil))
        #expect(FacetFilter<String>.only(["a"]).allows(nil) == false)
    }

    @Test func exceptAllowsAnyWhenNoValueIsExcluded() {
        let filter = FacetFilter<String>.except(["a"])
        #expect(filter.allowsAny(of: []))
        #expect(filter.allowsAny(of: ["b", "c"]))
        #expect(filter.allowsAny(of: ["b", "a"]) == false)
    }

    @Test func isSelectedMeansInTheSetForBothModes() {
        #expect(FacetFilter<String>.only(["a"]).isSelected("a"))
        #expect(FacetFilter<String>.except(["a"]).isSelected("a"))
        #expect(FacetFilter<String>.except(["a"]).isSelected("b") == false)
        #expect(FacetFilter<String>.all.isSelected("a") == false)
    }

    @Test func togglingUnderExceptKeepsTheMode() {
        let filter = FacetFilter<String>.except(["a"])
        #expect(filter.togglingSelection("b") == .except(["a", "b"]))
        #expect(filter.togglingSelection("a") == .all)
        #expect(FacetFilter<String>.all.togglingSelection("a") == .only(["a"]))
    }

    @Test func excludingReplacesOnlyAndAll() {
        #expect(FacetFilter<String>.only(["a"]).excluding("b") == .except(["b"]))
        #expect(FacetFilter<String>.all.excluding("b") == .except(["b"]))
    }

    @Test func excludingAddsToExcept() {
        #expect(FacetFilter<String>.except(["a"]).excluding("b") == .except(["a", "b"]))
        #expect(FacetFilter<String>.except(["a"]).excluding("a") == .except(["a"]))
    }

    @Test func valuesReturnTheSet() {
        #expect(FacetFilter<String>.all.values.isEmpty)
        #expect(FacetFilter<String>.only(["a"]).values == ["a"])
        #expect(FacetFilter<String>.except(["b"]).values == ["b"])
    }
}
