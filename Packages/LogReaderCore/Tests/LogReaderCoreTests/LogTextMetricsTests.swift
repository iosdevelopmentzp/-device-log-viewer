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
}
