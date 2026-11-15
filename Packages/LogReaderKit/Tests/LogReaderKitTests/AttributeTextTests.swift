import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct AttributeTextTests {

    private let tags = AttributeRule.list("tags", title: "Tags", prefix: "#", columnWidth: 110)
    private let category = AttributeRule.text("category", title: "Category", columnWidth: 90)

    @Test func listValuesGetThePrefix() {
        #expect(AttributeText.text(.list(["network", "auth"]), rule: tags) == "#network #auth")
        #expect(AttributeText.text(.list([]), rule: tags) == "")
    }

    @Test func textAndMissingValues() {
        #expect(AttributeText.text(.text("default"), rule: category) == "default")
        #expect(AttributeText.text(.none, rule: category) == "")
    }

    @Test func textsFollowTheProfileOrder() {
        let record = LogFixtures.record(message: "", level: nil, tags: ["network", "auth"], category: "default", source: nil)

        #expect(AttributeText.texts(of: record, profile: ProfileFixtures.textTrailing) == ["#network #auth", "default", ""])
    }

    @Test func missingAttributeValuesAreEmpty() {
        let record = LogFixtures.record(message: "", level: nil, tags: [], category: nil, source: nil)

        #expect(AttributeText.texts(of: record, profile: ProfileFixtures.jsonLines) == ["", "", "", "", ""])
    }
}
