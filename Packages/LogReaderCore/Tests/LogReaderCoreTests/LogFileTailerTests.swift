import Foundation
import Testing
@testable import LogReaderCore

struct LogFileTailerTests {

    private let header = "{\"v\":1,\"sep\":\"\\u001e\"}\n"

    @Test func readsInitialContentAppendsAndTruncation() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tailer-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data((header + "One DBG [default] [A:1] 2026-10-07 22:18:54.000\n\u{1E}").utf8).write(to: url)

        let source: any LogSource = LogFileTailer(url: url, profile: ProfileFixtures.textTrailing, readDelay: .milliseconds(10), pollInterval: .milliseconds(100))
        #expect(source.url == url)
        var iterator = source.events().makeAsyncIterator()

        guard case .batch(let first)? = await iterator.next() else {
            Issue.record("Expected initial batch")
            return
        }
        #expect(first.records.map(\.message) == ["One"])

        let writer = try FileHandle(forWritingTo: url)
        try writer.seekToEnd()
        try writer.write(contentsOf: Data("Two INF [default] [A:2] 2026-10-07 22:18:55.000\n\u{1E}".utf8))

        guard case .batch(let second)? = await iterator.next() else {
            Issue.record("Expected appended batch")
            return
        }
        #expect(second.records.map(\.message) == ["Two"])
        #expect(second.chunkIndex == 1)

        try writer.truncate(atOffset: 0)
        try writer.write(contentsOf: Data(header.utf8))
        try writer.close()

        guard case .reset? = await iterator.next() else {
            Issue.record("Expected reset after truncation")
            return
        }
        source.stop()
    }

    @Test func reportsMissingFileAndFinishesAfterStop() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).txt")
        let source: any LogSource = LogFileTailer(url: url, profile: ProfileFixtures.textTrailing, readDelay: .milliseconds(10), pollInterval: .milliseconds(100))
        var iterator = source.events().makeAsyncIterator()

        guard case .missing? = await iterator.next() else {
            Issue.record("Expected missing event")
            return
        }
        source.stop()
        let afterStop = await iterator.next()
        #expect(afterStop == nil)
    }
}
