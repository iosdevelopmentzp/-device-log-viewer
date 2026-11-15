import Foundation
import Testing
@testable import LogReaderCore

struct LogEntryTextTests {

    @Test func messageKeepsTheLinesBeforeTheHeader() throws {
        let profile = ProfileFixtures.textTrailing
        let text = ProfileFixtures.header + "first line\nHello DBG [default] [A:1] 2026-10-07 22:18:54.000\n  key: value\n\u{1E}"
        let content = try ProfileFixtures.content(text, profile: profile)
        let record = content.records[0]

        let parts = content.withBytes(of: record) { LogEntryText(profile: profile).messageAndBody($0, record: record) }

        #expect(parts.message == "first line\nHello")
        #expect(parts.body == "  key: value")
    }

    @Test func textLineCountMatchesTheDrawnLines() throws {
        let entries = [
            "Hello DBG [default] [A:1] 2026-10-07 22:18:54.000\n  key: value",
            "first\r\nHello DBG [default] [A:1] 2026-10-07 22:18:54.000\n\tkey:\tvalue\r\n  more\rlast",
            "no header here\nsecond line\n",
            String(repeating: "x", count: 300) + " INF [default] [A:1] 2026-10-07 22:18:54.000\n  data: " + String(repeating: "й", count: 500),
            "Only INF [default] [A:1] 2026-10-07 22:18:54.000"
        ]
        let text = ProfileFixtures.header + entries.map { $0 + ProfileFixtures.terminator }.joined()
        try expectMatchingLineCounts(text, profile: ProfileFixtures.textTrailing, recordCount: entries.count)
    }

    @Test func jsonLineCountMatchesTheDrawnLines() throws {
        let text = """
        {"timestamp":"2026-11-15T10:00:00Z","level":"info","message":"line one\\nline two\\twith a tab","userId":"42","payload":{"a":1}}
        {"timestamp":"2026-11-15T10:00:01Z","level":"error","message":"short"}
        not json at all

        """
        try expectMatchingLineCounts(text, profile: ProfileFixtures.jsonLines, recordCount: 3)
    }
}

// MARK: - Private

private extension LogEntryTextTests {

    func expectMatchingLineCounts(_ text: String, profile: LogProfile, recordCount: Int) throws {
        let content = try ProfileFixtures.content(text, profile: profile)
        let entryText = LogEntryText(profile: profile)
        #expect(content.records.count == recordCount)
        for record in content.records {
            for columns in [3, 7, 40, 200] {
                let drawn = content.withBytes(of: record) { bytes -> Int in
                    let parts = entryText.messageAndBody(bytes, record: record)
                    let joined = parts.body.isEmpty ? parts.message : parts.message + "\n" + parts.body
                    return LogTextMetrics.wrappedLineRanges(ofDrawableText: LogTextMetrics.drawableText(joined), columns: columns, maxLines: .max).count
                }
                let counted = content.withBytes(of: record) { entryText.wrappedLineCount($0, record: record, columns: columns, maxLines: .max) }
                let limited = content.withBytes(of: record) { entryText.wrappedLineCount($0, record: record, columns: columns, maxLines: 2) }
                #expect(counted == drawn, "\(record.message) at \(columns) columns")
                #expect(limited == min(drawn, 2))
            }
        }
    }
}
