import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct DataFileContentSearcherTests {

    @Test func countsMatchesInAFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DataFileContentSearcherTests-\(UUID().uuidString).txt")
        try Data("error one, error two".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let query = try #require(TextQuery("error"))

        #expect(try DataFileContentSearcher().countMatches(of: query, in: url, sizeLimit: 1_000) == .count(2))
    }

    @Test func missingFileIsSkipped() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DataFileContentSearcherTests-missing-\(UUID().uuidString).txt")
        let query = try #require(TextQuery("error"))

        #expect(try DataFileContentSearcher().countMatches(of: query, in: url, sizeLimit: 1_000) == .skipped)
    }
}
