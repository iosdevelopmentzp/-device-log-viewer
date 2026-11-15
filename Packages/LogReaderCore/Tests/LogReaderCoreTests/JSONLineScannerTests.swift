import Foundation
import Testing
@testable import LogReaderCore

struct JSONLineScannerTests {

    private func members(_ text: String) -> [(key: String, text: String, isNested: Bool)]? {
        var bytes = Array(text.utf8)
        return bytes.withUnsafeMutableBytes { buffer -> [(key: String, text: String, isNested: Bool)]? in
            let bytes = UnsafeRawBufferPointer(buffer)
            return JSONLineScanner.members(bytes, range: 0..<bytes.count)?.map { ($0.key, $0.value.text(in: bytes), $0.value.isNested) }
        }
    }

    @Test func readsTopLevelMembersInOrder() throws {
        let parsed = try #require(members(" {\"a\": \"x\", \"b\":12.5, \"c\": true, \"d\": null, \"e\": {\"n\":[1,\"]\"]}, \"f\": [1, 2] } "))

        #expect(parsed.map(\.key) == ["a", "b", "c", "d", "e", "f"])
        #expect(parsed[0].text == "x")
        #expect(parsed[1].text == "12.5")
        #expect(parsed[2].text == "true")
        #expect(parsed[3].text == "null")
        #expect(parsed[4].text == "{\"n\":[1,\"]\"]}")
        #expect(parsed[4].isNested)
        #expect(parsed[5].text == "[1, 2]")
    }

    @Test func decodesEscapes() throws {
        let parsed = try #require(members("{\"m\":\"a\\\"b\\\\c\\n\\t\\u0041\\u00e9\\ud83d\\ude00 \\/\"}"))
        #expect(parsed[0].text == "a\"b\\c\n\tAé😀 /")
    }

    @Test func rejectsBrokenObjects() {
        #expect(members("not json") == nil)
        #expect(members("{\"a\":1") == nil)
        #expect(members("{\"a\" 1}") == nil)
        #expect(members("{\"a\":\"unterminated}") == nil)
        #expect(members("[1,2]") == nil)
        #expect(members("{}")?.isEmpty == true)
    }

    @Test func stringItemsReadArrays() {
        #expect(JSONLineScanner.stringItems("[\"a\", \"b c\", 3]") == ["a", "b c", "3"])
        #expect(JSONLineScanner.stringItems("[]") == [])
        #expect(JSONLineScanner.stringItems("{\"a\":1}") == nil)
        #expect(JSONLineScanner.stringItems("[\"a\"") == nil)
    }

    @Test func jsonEntryParserMapsKeysAndLists() throws {
        var profile = LogProfile.jsonLines
        profile.attributes.append(.list("tags", title: "Tags", prefix: "#", columnWidth: 100))
        let parser = JSONEntryParser(rule: .standard, profile: profile)
        let text = "{\"msg\":\"hello\",\"messageType\":\"Fault\",\"time\":\"2026-10-07T22:18:54Z\",\"tags\":[\"a\",\"b\"],\"extra\":1,\"file\":\"X.swift\"}"
        var bytes = Array(text.utf8)
        let parsed = bytes.withUnsafeMutableBytes { buffer in
            parser.parse(UnsafeRawBufferPointer(buffer), range: 0..<buffer.count, maxFields: Int.max)
        }
        let entry = try #require(parsed)

        #expect(entry.message == "hello")
        #expect(entry.level == profile.level(id: "fault"))
        #expect(entry.timestamp == 1_791_411_534)
        #expect(entry.attributes[profile.attributeIndex(id: "tags")!] == .list(["a", "b"]))
        #expect(entry.attributes[profile.attributeIndex(id: "source")!] == .text("X.swift"))
        #expect(entry.fields.map(\.key) == ["extra"])
    }
}
