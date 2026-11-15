import Foundation
import Testing
@testable import LogReaderCore

struct LogTextMetricsTests {

    @Test func countsWrappedLinesAndRespectsLimit() {
        let text = Array("12345\n\nabcdefghijk\nпривет".utf8)
        text.withUnsafeBytes { bytes in
            #expect(LogTextMetrics.wrappedLineCount(bytes, columns: 5, maxLines: 100) == 1 + 1 + 3 + 2)
            #expect(LogTextMetrics.wrappedLineCount(bytes, columns: 5, maxLines: 3) == 3)
        }
    }

    @Test func tabsTakeFourColumnsAndCarriageReturnsBreakLines() {
        #expect(LogTextMetrics.wrappedLineCount("a\tb", columns: 5, maxLines: 10) == 2)
        #expect(LogTextMetrics.wrappedLineCount("a\r\nb\rc\n", columns: 5, maxLines: 10) == 4)
        #expect(LogTextMetrics.drawableText("a\tb\r\nc\rd") == "a    b\nc\nd")
        #expect(LogTextMetrics.drawableText("plain") == "plain")
    }

    @Test func lineRangesAreUTF16RangesOfTheWrappedLines() {
        let text = "12345\n\nabcdefghijk\nпри😀вет"

        let ranges = LogTextMetrics.wrappedLineRanges(ofDrawableText: text, columns: 5, maxLines: 100)

        #expect(ranges == [
            NSRange(location: 0, length: 5),
            NSRange(location: 6, length: 0),
            NSRange(location: 7, length: 5),
            NSRange(location: 12, length: 5),
            NSRange(location: 17, length: 1),
            NSRange(location: 19, length: 6),
            NSRange(location: 25, length: 2)
        ])
        #expect((text as NSString).substring(with: ranges[5]) == "при😀в")
        #expect(LogTextMetrics.wrappedLineCount(text, columns: 5, maxLines: 100) == ranges.count)
        #expect(LogTextMetrics.wrappedLineRanges(ofDrawableText: text, columns: 5, maxLines: 2).count == 2)
    }
}
