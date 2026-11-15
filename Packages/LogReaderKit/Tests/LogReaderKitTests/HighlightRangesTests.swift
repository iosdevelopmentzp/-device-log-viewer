import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct HighlightRangesTests {

    @Test func noQueriesGiveNoRanges() {
        #expect(HighlightRanges.ranges(of: [], in: "text").isEmpty)
    }

    @Test func rangesAreSortedAndMerged() {
        let queries = [TextQuery("cd"), TextQuery("abc"), TextQuery("x"), TextQuery("bc")].compactMap { $0 }

        let ranges = HighlightRanges.ranges(of: queries, in: "abcd x abc")

        #expect(ranges == [
            NSRange(location: 0, length: 4),
            NSRange(location: 5, length: 1),
            NSRange(location: 7, length: 3)
        ])
    }

    @Test func touchingRangesMerge() {
        let queries = [TextQuery("ab"), TextQuery("cd")].compactMap { $0 }

        #expect(HighlightRanges.ranges(of: queries, in: "abcd") == [NSRange(location: 0, length: 4)])
    }
}
