import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct LogTableColumnTests {

    @Test func allColumnsPutTheAttributesBeforeTheMessage() {
        let columns = LogTableColumn.all(in: ProfileFixtures.textTrailing)

        #expect(columns.map(\.rawValue) == ["number", "time", "delta", "level", "tags", "category", "source", "message"])
    }

    @Test func attributeColumnsKnowTheirAttribute() {
        #expect(LogTableColumn.attribute("tags").attributeID == "tags")
        #expect(LogTableColumn.attribute("tags") == LogTableColumn(rawValue: "tags"))
        #expect(LogTableColumn.level.attributeID == nil)
        #expect(LogTableColumn.number.isFixed)
        #expect(LogTableColumn.attribute("subsystem").isFixed == false)
    }

    @Test func onlyTheMessageCannotBeHidden() {
        let columns = LogTableColumn.all(in: ProfileFixtures.jsonLines)

        #expect(columns.filter { $0.canHide == false } == [.message])
    }

    @Test func columnsEncodeAsTheirRawValue() throws {
        let columns: [LogTableColumn] = [.delta, .attribute("tags")]

        let data = try JSONEncoder().encode(columns)

        #expect(String(decoding: data, as: UTF8.self) == #"["delta","tags"]"#)
        #expect(try JSONDecoder().decode([LogTableColumn].self, from: data) == columns)
    }
}
