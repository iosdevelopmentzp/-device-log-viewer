import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct ExportEntriesEncoderTests {

    @Test func logExportIsReadBackWithTheSameEntries() throws {
        let content = makeContent()

        let data = ExportEntriesEncoder.logData(content: content, recordIndices: [0, 1, 2])
        let exported = try reindex(data)

        #expect(exported.records.count == 3)
        #expect(exported.records.map(exported.text(of:)) == content.records.map(content.text(of:)))
        #expect(data.starts(with: Data(LogFixtures.header.utf8)))
    }

    @Test func logExportOfASubsetKeepsOnlyThoseEntries() throws {
        let content = makeContent()

        let exported = try reindex(ExportEntriesEncoder.logData(content: content, recordIndices: [0, 2]))

        #expect(exported.records.map(exported.text(of:)) == [content.records[0], content.records[2]].map(content.text(of:)))
    }

    @Test func jsonExportIsAnArrayWithEntryNumbers() throws {
        let content = makeContent()

        let data = ExportEntriesEncoder.jsonData(content: content, recordIndices: [1, 2])
        let array = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(array.count == 2)
        #expect(array.compactMap { $0["number"] as? Int } == [2, 3])
        #expect(array.compactMap { $0["message"] as? String } == ["Payment failed", "Debug noise"])
    }

    @Test func emptyJSONExportIsAnEmptyArray() throws {
        let data = ExportEntriesEncoder.jsonData(content: makeContent(), recordIndices: [])

        #expect(try JSONSerialization.jsonObject(with: data) as? [Any] != nil)
    }

    @Test func dataPicksTheEncoderByFormat() {
        let content = makeContent()

        #expect(
            ExportEntriesEncoder.data(content: content, recordIndices: [0], format: .log)
                == ExportEntriesEncoder.logData(content: content, recordIndices: [0])
        )
        #expect(
            ExportEntriesEncoder.data(content: content, recordIndices: [0], format: .json)
                == ExportEntriesEncoder.jsonData(content: content, recordIndices: [0])
        )
    }

    @Test func separatorFramingWritesTheSeparatorWithoutAHeader() throws {
        var profile = ProfileFixtures.textTrailing
        profile.framing = .separator("\u{1E}")
        let content = try makeContent(LogFixtures.sample.map { $0 + "\u{1E}" }.joined(), profile: profile)

        let data = ExportEntriesEncoder.logData(content: content, recordIndices: [0, 2])
        let exported = try reindex(data, profile: profile)

        #expect(data.starts(with: Data(LogFixtures.header.utf8)) == false)
        #expect(data.filter { $0 == 0x1E }.count == 2)
        #expect(exported.records.map(exported.text(of:)) == [content.records[0], content.records[2]].map(content.text(of:)))
    }

    @Test func linesFramingWritesNewlineTerminatedEntries() throws {
        let profile = ProfileFixtures.jsonLines
        let lines = [
            #"{"timestamp":"2026-10-07T22:18:54.000Z","level":"info","message":"first"}"#,
            #"{"timestamp":"2026-10-07T22:18:55.000Z","level":"error","message":"second"}"#
        ]
        let content = try makeContent(lines.map { $0 + "\n" }.joined(), profile: profile)

        let data = ExportEntriesEncoder.logData(content: content, recordIndices: [0, 1])
        let exported = try reindex(data, profile: profile)

        #expect(data.contains(0x1E) == false)
        #expect(data.last == UInt8(ascii: "\n"))
        #expect(exported.records.map(exported.text(of:)) == content.records.map(content.text(of:)))
    }

    private func makeContent() -> LogContent {
        var fixtures = LogFixtures()
        var content = LogContent(profile: LogFixtures.profile)
        content.append(fixtures.batch(LogFixtures.sample))
        return content
    }

    private func makeContent(_ text: String, profile: LogProfile) throws -> LogContent {
        var indexer = LogIndexer(profile: profile)
        let consumed = indexer.consume(Data(text.utf8))
        let batch = try #require(consumed)
        var content = LogContent(profile: profile)
        content.append(batch)
        return content
    }

    private func reindex(_ data: Data) throws -> LogContent {
        try reindex(data, profile: LogFixtures.profile)
    }

    private func reindex(_ data: Data, profile: LogProfile) throws -> LogContent {
        var indexer = LogIndexer(profile: profile)
        let consumed = indexer.consume(data)
        let batch = try #require(consumed)
        var content = LogContent(profile: profile)
        content.append(batch)
        return content
    }
}
