import Foundation
import Testing
@testable import LogReaderCore

struct FacetCountsTests {

    private let profile = ProfileFixtures.textTrailing
    private let tags = FacetColumn.attribute("tags")
    private let category = FacetColumn.attribute("category")
    private let source = FacetColumn.attribute("source")

    private func makeRecords() throws -> [LogRecord] {
        let text = ProfileFixtures.header
            + "One #network #auth INF [websocket] [Sockets:10] 2026-10-07 22:18:54.000\n\u{1E}"
            + "Two #network ERR [default] [Store:20] 2026-10-07 22:18:55.000\n\u{1E}"
            + "Three #b DBG [default] [Store:30] 2026-10-07 22:18:56.000\n\u{1E}"
            + "Four #a DBG [default] [file10:1] 2026-10-07 22:18:57.000\n\u{1E}"
            + "Five DBG [default] [file9:1] 2026-10-07 22:18:58.000\n\u{1E}"
        return try ProfileFixtures.records(text, profile: profile)
    }

    @Test func countsEveryColumn() throws {
        var counts = FacetCounts(profile: profile)
        counts.add(try makeRecords()[...])

        #expect(counts.count(of: "debug", in: .level) == 3)
        #expect(counts.count(of: "network", in: tags) == 2)
        #expect(counts.count(of: "default", in: category) == 4)
        #expect(counts.count(of: "Store", in: source) == 2)
        #expect(counts.count(of: "missing", in: tags) == 0)
    }

    @Test func addAccumulatesSlices() throws {
        let records = try makeRecords()
        var counts = FacetCounts(profile: profile)
        counts.add(records[0..<2])
        counts.add(records[2...])

        var whole = FacetCounts(profile: profile)
        whole.add(records[...])
        #expect(counts == whole)
    }

    @Test func levelEntriesListEveryLevelInOrder() throws {
        var counts = FacetCounts(profile: profile)
        counts.add(try makeRecords()[...])

        let entries = counts.entries(in: .level)
        #expect(entries.map(\.value) == profile.levels.map(\.id))
        #expect(entries.map(\.count) == [3, 1, 0, 0, 1, 0])
        #expect(FacetCounts(profile: profile).entries(in: .level).allSatisfy { $0.count == 0 })
    }

    @Test func otherEntriesSortByCountThenName() throws {
        var counts = FacetCounts(profile: profile)
        counts.add(try makeRecords()[...])

        #expect(counts.entries(in: tags).map(\.value) == ["network", "a", "auth", "b"])
        #expect(counts.entries(in: source).map(\.value) == ["Store", "file9", "file10", "Sockets"])
        #expect(counts.entries(in: category) == [
            FacetCounts.Entry(value: "default", count: 4),
            FacetCounts.Entry(value: "websocket", count: 1)
        ])
    }

    @Test func nonFacetAttributesAreNotCounted() throws {
        let profile = ProfileFixtures.jsonLines
        var counts = FacetCounts(profile: profile)
        let records = try ProfileFixtures.records("{\"message\":\"m\",\"thread\":\"t1\",\"process\":\"App\"}\n", profile: profile)
        counts.add(records[...])

        #expect(counts.entries(in: .attribute("thread")).isEmpty)
        #expect(counts.count(of: "App", in: .attribute("process")) == 1)
    }

    @Test func removeAllClearsCounts() throws {
        var counts = FacetCounts(profile: profile)
        counts.add(try makeRecords()[...])
        counts.removeAll()

        #expect(counts == FacetCounts(profile: profile))
        #expect(counts.entries(in: tags).isEmpty)
    }
}
