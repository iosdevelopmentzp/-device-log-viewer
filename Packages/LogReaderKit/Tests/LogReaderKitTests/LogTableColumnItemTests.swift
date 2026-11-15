import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct LogTableColumnItemTests {

    @Test func itemsFollowTheProfileAttributes() {
        let items = LogTableColumnItem.all(in: ProfileFixtures.textTrailing)

        #expect(items.map(\.id) == ["number", "time", "delta", "level", "tags", "category", "source", "message"])
        #expect(items.map(\.kind) == [.number, .time, .delta, .level, .list, .text, .text, .message])
        #expect(items.map(\.title) == ["#", "Time", "Δ", "Level", "Tags", "Category", "Source", "Message"])
        #expect(items.map(\.width) == [64, 104, 70, 44, 110, 90, 170, 900])
        #expect(items.map(\.attributeIndex) == [nil, nil, nil, nil, 0, 1, 2, nil])
        #expect(items.filter(\.alignsTrailing).map(\.column) == [.number, .delta])
        #expect(items.filter(\.isMessage).map(\.column) == [.message])
    }

    @Test func onlyFacetAttributesGetAFacet() {
        let items = LogTableColumnItem.all(in: ProfileFixtures.jsonLines)

        #expect(items.map(\.facet) == [
            nil, nil, nil, .level,
            .attribute("subsystem"), .attribute("category"), .attribute("source"), .attribute("process"), nil,
            nil
        ])
    }
}
