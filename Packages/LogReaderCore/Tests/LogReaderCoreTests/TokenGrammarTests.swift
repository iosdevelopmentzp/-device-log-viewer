import Foundation
import Testing
@testable import LogReaderCore

struct TokenGrammarTests {

    private func parse(_ line: String, profile: LogProfile) -> LogHeaderLine? {
        let grammar = LogEntryGrammar(profile: profile)
        var bytes = Array(line.utf8)
        return bytes.withUnsafeMutableBytes { buffer in
            grammar.headerLine(UnsafeRawBufferPointer(buffer), lineStart: 0, lineEnd: buffer.count)
        }
    }

    private func message(_ line: String, _ header: LogHeaderLine) -> String {
        String(decoding: Array(line.utf8)[header.messageRange], as: UTF8.self)
    }

    @Test func trailingGrammarReadsEveryToken() throws {
        let profile = ProfileFixtures.textTrailing
        let line = "Hello world #a #b WRN [cat] [File:12] 2026-10-07 22:18:54.000  \r"
        let header = try #require(parse(line, profile: profile))

        #expect(message(line, header) == "Hello world")
        #expect(header.level == profile.level(id: "warning"))
        #expect(header.attributes == [.list(["a", "b"]), .text("cat"), .text("File:12")])
        #expect(header.timestamp != nil)
    }

    @Test func trailingGrammarRollsBackCategoryWithoutLevel() throws {
        let profile = ProfileFixtures.textTrailing
        let line = "[REQUEST] [File:12] 2026-10-07 22:18:54.000"
        let header = try #require(parse(line, profile: profile))

        #expect(message(line, header) == "[REQUEST]")
        #expect(header.attributes == [.none, .none, .text("File:12")])
    }

    @Test func trailingGrammarNeedsBoundaries() {
        let profile = ProfileFixtures.textTrailing
        #expect(parse("x2026-10-07 22:18:54.000", profile: profile) == nil)
        #expect(parse("xINF", profile: profile) == nil)
        #expect(parse("a[cat] INF", profile: profile)?.attributes[1] == AttributeValue.none)
        #expect(parse("[a]b] INF", profile: profile)?.attributes[1] == AttributeValue.none)
        #expect(parse("[] INF", profile: profile)?.attributes[1] == AttributeValue.none)
    }

    @Test func requiredTokenMakesTheLineUnrecognized() {
        var profile = ProfileFixtures.textTrailing
        profile.entry = .trailing([.time(required: true), .level(required: false)])
        #expect(parse("Hello INF", profile: profile) == nil)
        #expect(parse("Hello INF 2026-10-07 22:18:54.000", profile: profile)?.level == profile.level(id: "info"))
    }

    @Test func grammarWithoutTimeOrLevelIsRecognizedByAnyToken() throws {
        var profile = ProfileFixtures.textTrailing
        profile.entry = .trailing([.delimited("category", open: "<", close: ">", pattern: nil, requires: nil)])
        let header = try #require(parse("Message <ui>", profile: profile))
        #expect(header.attributes[1] == .text("ui"))
        #expect(parse("Message", profile: profile) == nil)
    }

    @Test func literalAndWordTokens() throws {
        var profile = ProfileFixtures.textTrailing
        profile.entry = .leading([.time(required: true), .literal("|"), .word("category", required: true), .literal("-")])
        profile.timestamp = .pattern("HH:mm:ss", timeZone: "UTC")
        let line = "10:00:01 | net - Request sent"
        let header = try #require(parse(line, profile: profile))

        #expect(message(line, header) == "Request sent")
        #expect(header.attributes[1] == .text("net"))
        #expect(header.timestamp == 36_001)
        #expect(parse("10:00:01 net - Request sent", profile: profile) == nil)
    }

    @Test func leadingLevelWithDelimitersAndTagsAfterwards() throws {
        let profile = ProfileFixtures.textLeading
        let line = "2026-01-05 10:00:02.000 [DEBUG] #slow #io Done"
        let header = try #require(parse(line, profile: profile))

        #expect(message(line, header) == "Done")
        #expect(header.level == profile.level(id: "debug"))
        #expect(header.attributes == [.none, .list(["slow", "io"])])
        #expect(parse("2026-01-05 10:00:02.000 DEBUG Done", profile: profile) == nil)
        #expect(parse("2026-01-05 10:00:02.000 [WHAT] Done", profile: profile) == nil)
    }

    @Test func wordTokenMappedToListAttributeStoresAList() throws {
        var profile = ProfileFixtures.textTrailing
        profile.entry = .trailing([.word("tags", required: true)])
        let header = try #require(parse("Hi there", profile: profile))
        #expect(header.attributes[0] == .list(["there"]))
    }
}
