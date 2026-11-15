import Foundation
import Testing
@testable import LogReaderKit

struct JSONTreeBuilderTests {

    @Test func nestedObjectAndArrayGiveSortedChildrenWithKeyPaths() throws {
        let tree = try #require(JSONTreeBuilder.build(#"{"user":{"name":"Ann","id":7},"items":[{"name":"a"},2]}"#, limit: 100))

        #expect(tree.id == "$")
        #expect(tree.key == "$")
        #expect(tree.kind == .object)
        #expect(tree.valueText == "{2}")
        #expect(tree.children.map(\.key) == ["items", "user"])
        let items = tree.children[0]
        #expect(items.id == "$.items")
        #expect(items.kind == .array)
        #expect(items.valueText == "[2]")
        #expect(items.children.map(\.key) == ["[0]", "[1]"])
        #expect(items.children[0].children[0].id == "$.items[0].name")
        #expect(tree.children[1].children.map(\.id) == ["$.user.id", "$.user.name"])
    }

    @Test func keysThatAreNotIdentifiersUseBrackets() throws {
        let tree = try #require(JSONTreeBuilder.build(#"{"a.b":1,"2x":2,"ok_1":3}"#, limit: 100))

        #expect(tree.children.map(\.id) == [#"$["2x"]"#, #"$["a.b"]"#, "$.ok_1"])
    }

    @Test func scalarsAreRendered() throws {
        let tree = try #require(JSONTreeBuilder.build(#"[1, 1.0, 2.5, -3, true, false, null, "a \"b\" / c", 12345678901234]"#, limit: 100))

        #expect(tree.children.map(\.valueText) == ["1", "1", "2.5", "-3", "true", "false", "null", #""a \"b\" / c""#, "12345678901234"])
        #expect(tree.children.map(\.kind) == [.number, .number, .number, .number, .bool, .bool, .null, .string, .number])
        #expect(tree.children.allSatisfy { $0.isContainer == false })
    }

    @Test func invalidJSONGivesNil() {
        #expect(JSONTreeBuilder.build("{not json", limit: 100) == nil)
    }

    @Test func scalarTopLevelGivesNil() {
        #expect(JSONTreeBuilder.build("42", limit: 100) == nil)
        #expect(JSONTreeBuilder.build(#""text""#, limit: 100) == nil)
    }

    @Test func treeOverTheLimitGivesNil() {
        #expect(JSONTreeBuilder.build("[1,2,3]", limit: 4) != nil)
        #expect(JSONTreeBuilder.build("[1,2,3,4]", limit: 4) == nil)
    }

    @Test func subtreeJSONParsesBackToTheSameValue() throws {
        let json = #"{"items":[1,2.5,"x",null,true],"user":{"name":"Ann \"A\"","tags":[]},"empty":{}}"#
        let tree = try #require(JSONTreeBuilder.build(json, limit: 100))

        let original = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary
        let roundTrip = try JSONSerialization.jsonObject(with: Data(JSONTreeBuilder.subtreeJSON(of: tree).utf8)) as? NSDictionary
        #expect(original == roundTrip)
        #expect(JSONTreeBuilder.subtreeJSON(of: tree.children[1]) == "[\n  1,\n  2.5,\n  \"x\",\n  null,\n  true\n]")
    }

    @Test func plainValueRemovesQuotesOfStrings() throws {
        let tree = try #require(JSONTreeBuilder.build(#"["a \"b\"", 3]"#, limit: 100))

        #expect(JSONTreeBuilder.plainValue(of: tree.children[0]) == #"a "b""#)
        #expect(JSONTreeBuilder.plainValue(of: tree.children[1]) == "3")
    }
}
