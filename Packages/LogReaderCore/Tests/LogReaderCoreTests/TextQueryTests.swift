import Foundation
import Testing
@testable import LogReaderCore

struct TextQueryTests {

    @Test func plainQueryIsNotRegex() throws {
        let query = try #require(TextQuery("a.c"))
        #expect(query.isRegex == false)
        #expect(query.matches("abc") == false)
        #expect(query.matches("xA.Cx"))
    }

    @Test func regexMatchesStrings() throws {
        let query = try TextQuery.regex("user/\\d+/event")
        #expect(query.isRegex)
        #expect(query.text == "user/\\d+/event")
        #expect(query.matches("on event user/42/event"))
        #expect(query.matches("on event user/x/event") == false)
    }

    @Test func regexMatchesBytes() throws {
        let query = try TextQuery.regex("^Payment\\s+failed")
        let matches = Data("Payment   failed ERR".utf8).withUnsafeBytes { query.matches($0) }
        let misses = Data("No Payment failed".utf8).withUnsafeBytes { query.matches($0) }
        #expect(matches)
        #expect(misses == false)
    }

    @Test func regexIsCaseInsensitive() throws {
        let query = try TextQuery.regex("привет|socket")
        #expect(query.matches("SOCKET open"))
        #expect(query.matches("ПРИВЕТ мир"))
    }

    @Test func regexRangesReturnEveryMatch() throws {
        let query = try TextQuery.regex("a\\d")
        let string = "a1 b2 A3 a"
        let ranges = query.ranges(in: string)
        #expect(ranges.map { String(string[$0]) } == ["a1", "A3"])
    }

    @Test func regexRangesSkipEmptyMatches() throws {
        let query = try TextQuery.regex("x*")
        let string = "abxxc"
        #expect(query.ranges(in: string).map { String(string[$0]) } == ["xx"])
    }

    @Test func invalidPatternThrows() {
        #expect(throws: (any Error).self) { try TextQuery.regex("a(b") }
    }

    @Test func equalityComparesTextAndKind() throws {
        let plain = try #require(TextQuery("abc"))
        let regex = try TextQuery.regex("abc")
        #expect(plain == TextQuery("abc"))
        #expect(regex == (try TextQuery.regex("abc")))
        #expect(plain != regex)
    }

    @Test func countMatchesCountsASCIIHitsIgnoringCase() throws {
        let query = try #require(TextQuery("socket"))
        let count = Data("Socket open\nsocket closed\nSOCKETSOCKET\nnone".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        let none = Data("nothing here".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        #expect(count == 4)
        #expect(none == 0)
    }

    @Test func countMatchesCountsNonOverlappingHits() throws {
        let query = try #require(TextQuery("aa"))
        let count = Data("aaaaa".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        #expect(count == 2)
    }

    @Test func countMatchesCountsNonASCIIHits() throws {
        let query = try #require(TextQuery("привет"))
        let count = Data("Привет мир, ПРИВЕТ, привет".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        let asciiOnly = Data("hello world".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        #expect(count == 3)
        #expect(asciiOnly == 0)
    }

    @Test func countMatchesCountsRegexHits() throws {
        let query = try TextQuery.regex("user/\\d+")
        let count = Data("user/1 user/x USER/22 user/3".utf8).withUnsafeBytes { query.countMatches(in: $0) }
        #expect(count == 3)
    }
}
