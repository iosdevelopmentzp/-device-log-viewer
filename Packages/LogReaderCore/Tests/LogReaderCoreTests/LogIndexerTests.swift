import Foundation
import Testing
@testable import LogReaderCore

struct LogIndexerTests {

    private let profile = ProfileFixtures.textTrailing
    private let header = ProfileFixtures.header
    private let terminator = ProfileFixtures.terminator

    @Test func parsesStructuredEntries() throws {
        let text = header
            + "Core API client configured DBG [default] [CoreServices:46] 2026-10-07 22:18:54.787\n  authorization: <empty>\n" + terminator
            + "[NETWORK REQUEST] #network #auth ERR [default] [ApiService:229] 2026-10-07 22:18:54.992\n  URL: /v1/media\n  method: GET" + terminator

        var indexer = LogIndexer(profile: profile)
        let consumed = indexer.consume(Data(text.utf8))
        let batch = try #require(consumed)

        #expect(indexer.format == .separated(0x1E))
        #expect(batch.records.count == 2)

        let first = batch.records[0]
        #expect(first.message == "Core API client configured")
        #expect(first.level == profile.level(id: "debug"))
        #expect(profile.value(of: first, attributeID: "category").text == "default")
        #expect(profile.source(of: first) == "CoreServices:46")
        #expect(first.detailPreview == "authorization: <empty>")
        #expect(first.offset == header.utf8.count)
        #expect(first.isStructured)
        let expectedTime = try #require(Self.utcDate("2026-10-07 22:18:54.787"))
        #expect(abs((first.timestamp ?? 0) - expectedTime.timeIntervalSince1970) < 0.0005)

        let second = batch.records[1]
        #expect(second.message == "[NETWORK REQUEST]")
        #expect(profile.value(of: second, attributeID: "tags").values == ["network", "auth"])
        #expect(second.level == profile.level(id: "error"))
        #expect(second.metadataRange == 17..<(second.length - "\n  URL: /v1/media\n  method: GET".utf8.count))
    }

    @Test func keepsIncompleteEntryUntilTerminatorArrives() throws {
        var indexer = LogIndexer(profile: profile)
        let headerOnly = indexer.consume(Data(header.utf8))
        #expect(headerOnly == nil)
        let incomplete = indexer.consume(Data("First DBG [default] [A:1] 2026-10-07 22:18:54.787".utf8))
        #expect(incomplete == nil)

        let consumed = indexer.consume(Data((terminator + "Second INF [default] [B:2] 2026-10-07 22:18:55.000").utf8))

        let batch = try #require(consumed)
        #expect(batch.records.map(\.message) == ["First"])
        #expect(batch.chunkIndex == 0)

        let consumedNext = indexer.consume(Data(terminator.utf8))

        let next = try #require(consumedNext)
        #expect(next.records.map(\.message) == ["Second"])
        #expect(next.chunkIndex == 1)
    }

    @Test func productionFormatWithoutCategory() throws {
        let text = header + "[NETWORK REQUEST] #network DBG [ApiService:229] 2026-10-07 22:18:54.992" + terminator
        let record = try #require(ProfileFixtures.records(text, profile: profile).first)

        #expect(record.message == "[NETWORK REQUEST]")
        #expect(profile.value(of: record, attributeID: "category") == .none)
        #expect(profile.source(of: record) == "ApiService:229")
        #expect(profile.value(of: record, attributeID: "tags").values == ["network"])
    }

    @Test func messageInBracketsIsNotCategoryWithoutLevel() throws {
        let text = header + "[NETWORK REQUEST] [ApiService:229] 2026-10-07 22:18:54.992" + terminator
        let record = try #require(ProfileFixtures.records(text, profile: profile).first)

        #expect(record.message == "[NETWORK REQUEST]")
        #expect(profile.value(of: record, attributeID: "category") == .none)
        #expect(record.level == nil)
        #expect(record.timestamp != nil)
    }

    @Test func wordWithHashIsNotATagWithoutLevel() throws {
        let text = header + "Issue #12 [ApiService:229] 2026-10-07 22:18:54.992" + terminator
        let record = try #require(ProfileFixtures.records(text, profile: profile).first)

        #expect(record.message == "Issue #12")
        #expect(profile.value(of: record, attributeID: "tags") == .none)
    }

    @Test func multiLineMessageFindsHeaderOnLaterLine() throws {
        let text = header + "Line one\nLine two WRN [default] [File:7] 2026-10-07 22:18:54.992\n  key: value" + terminator
        let record = try #require(ProfileFixtures.records(text, profile: profile).first)

        #expect(record.level == profile.level(id: "warning"))
        #expect(record.message == "Line one ⏎ Line two")
        #expect(record.detailPreview == "key: value")
    }

    @Test func legacyFileWithoutHeaderUsesLines() throws {
        var indexer = LogIndexer(profile: profile)
        let consumed = indexer.consume(Data("plain one\nplain two\n".utf8))
        let batch = try #require(consumed)

        #expect(indexer.format == .lines)
        #expect(batch.records.map(\.message) == ["plain one", "plain two"])
        #expect(batch.records.allSatisfy { $0.level == nil && $0.isStructured == false })
        #expect(batch.records[0].attributes == [.none, .none, .none])
    }

    @Test func entryDetailsSplitFieldsAndPrettyPrintJSON() throws {
        let text = header
            + "on event user/1/event DBG [websocket] [Sockets:300] 2026-10-07 22:18:54.992\n  payload: {\"b\":1,\"a\":\"x\"}\n  HEADER FIELDS: \n    Alt-Svc: h3\n" + terminator
        let content = try ProfileFixtures.content(text, profile: profile)
        let record = content.records[0]

        let details = LogEntryDetails.parse(content.text(of: record), record: record, profile: profile)

        #expect(details.message == "on event user/1/event")
        #expect(details.fields.map(\.key) == ["payload", "HEADER FIELDS"])
        #expect(details.fields[0].prettyValue == "{\n  \"a\" : \"x\",\n  \"b\" : 1\n}")
        #expect(details.fields[1].value == "  Alt-Svc: h3")
    }

    @Test func messageAndBodySkipsHeaderMetadata() throws {
        let text = header + "Hello #tag DBG [default] [A:1] 2026-10-07 22:18:54.000\n  key: value\n\u{1E}"
        let content = try ProfileFixtures.content(text, profile: profile)
        let record = content.records[0]

        let parts = LogEntryDetails.messageAndBody(content.text(of: record), record: record, profile: profile)

        #expect(parts.message == "Hello")
        #expect(parts.body == "  key: value")
    }

    @Test func fixedSeparatorFramingNeedsNoHeader() throws {
        var profile = profile
        profile.framing = .separator("\u{1E}")
        var indexer = LogIndexer(profile: profile)
        let consumed = indexer.consume(Data("One DBG [A:1] 2026-10-07 22:18:54.000\n\u{1E}Two INF [A:2] 2026-10-07 22:18:55.000\n\u{1E}".utf8))
        let batch = try #require(consumed)

        #expect(indexer.format == .separated(0x1E))
        #expect(batch.records.map(\.message) == ["One", "Two"])
    }

    @Test func linesFramingJoinsUnrecognizedLines() throws {
        let profile = ProfileFixtures.textLeading
        let text = "2026-01-05 10:00:00.000 [INFO] [Network] Request sent\n"
            + "2026-01-05 10:00:01.000 [ERROR] [Network] Request failed\n"
            + "  reason: timeout\n"
            + "  retry: 2\n"
            + "2026-01-05 10:00:02.000 [DEBUG] #slow Done\n"
        let records = try ProfileFixtures.records(text, profile: profile)

        #expect(records.map(\.message) == ["Request sent", "Request failed", "Done"])
        #expect(records[1].detailPreview == "reason: timeout")
        #expect(records[1].level == profile.level(id: "error"))
        #expect(profile.value(of: records[1], attributeID: "category").text == "Network")
        #expect(profile.value(of: records[2], attributeID: "tags").values == ["slow"])
        #expect(records[2].metadataRange == 0..<"2026-01-05 10:00:02.000 [DEBUG] #slow ".utf8.count)
        let expectedTime = try #require(Self.date("2026-01-05 10:00:00.000", zone: "Europe/Kyiv"))
        #expect(abs((records[0].timestamp ?? 0) - expectedTime.timeIntervalSince1970) < 0.0005)
    }

    @Test func leadingGrammarKeepsMessageSearchableWithoutMetadata() throws {
        let profile = ProfileFixtures.textLeading
        let content = try ProfileFixtures.content("2026-01-05 10:00:00.000 [INFO] [Network] Request sent\n  detail: INFO text\n", profile: profile)
        var filter = LogFilter.all
        filter.text = "INFO"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<1, filter: filter) == [0])

        let parts = LogEntryDetails.messageAndBody(content.text(of: content.records[0]), record: content.records[0], profile: profile)
        #expect(parts.message == "Request sent")
        #expect(parts.body == "  detail: INFO text")
    }

    @Test func regexGrammarUsesNamedGroups() throws {
        let profile = ProfileFixtures.regex
        let text = "12:00:01 I net.http - Request sent\nnoise line\n12:00:02 E store - Payment failed\n"
        let records = try ProfileFixtures.records(text, profile: profile)

        #expect(records.map(\.message) == ["Request sent", "noise line", "Payment failed"])
        #expect(records[0].level == profile.level(id: "info"))
        #expect(records[1].isStructured == false)
        #expect(records[2].level == profile.level(id: "error"))
        #expect(profile.value(of: records[2], attributeID: "module").text == "store")
        #expect(abs((records[0].timestamp ?? 0) - 43_201) < 0.001)
        #expect(records[2].metadataRange == 0..<"12:00:02 E store - ".utf8.count)
    }

    @Test func jsonLinesProfileReadsOSLoggerLikeEntries() throws {
        let profile = ProfileFixtures.jsonLines
        let text = """
        {"timestamp":"2026-10-07T22:18:54.787Z","level":"error","subsystem":"com.example.app","category":"network","message":"Request failed","file":"ApiService.swift","line":229,"process":"App","thread":"0x1","payload":{"code":500,"url":"/v1/a"}}
        {"timestamp":1759875535.5,"level":"Info","message":"Привет \\"мир\\"\\nsecond line","category":"ui"}
        not json at all

        """
        let content = try ProfileFixtures.content(text, profile: profile)
        let records = content.records

        #expect(records.count == 3)
        #expect(records[0].message == "Request failed")
        #expect(records[0].level == profile.level(id: "error"))
        #expect(profile.value(of: records[0], attributeID: "subsystem").text == "com.example.app")
        #expect(profile.value(of: records[0], attributeID: "category").text == "network")
        #expect(profile.source(of: records[0]) == "ApiService.swift:229")
        #expect(profile.sourceReference(of: records[0]) == SourceReference(fileName: "ApiService.swift", line: 229))
        #expect(records[0].detailPreview == "payload: {\"code\":500,\"url\":\"/v1/a\"}")
        let expectedTime = try #require(Self.utcDate("2026-10-07 22:18:54.787"))
        #expect(abs((records[0].timestamp ?? 0) - expectedTime.timeIntervalSince1970) < 0.0005)

        #expect(records[1].message == "Привет \"мир\" ⏎ second line")
        #expect(records[1].level == profile.level(id: "info"))
        #expect(records[1].timestamp == 1759875535.5)
        #expect(records[2].isStructured == false)
        #expect(records[2].message == "not json at all")

        let details = LogEntryDetails.parse(content.text(of: records[0]), record: records[0], profile: profile)
        #expect(details.message == "Request failed")
        #expect(details.fields.map(\.key) == ["payload"])
        #expect(details.fields[0].prettyValue == "{\n  \"code\" : 500,\n  \"url\" : \"/v1/a\"\n}")

        var filter = LogFilter.all
        filter.text = "мир"
        #expect(try LogFilterEngine.indices(in: content, range: 0..<3, filter: filter) == [1])
    }

    static func utcDate(_ string: String) -> Date? {
        date(string, zone: "UTC")
    }

    static func date(_ string: String, zone: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.date(from: string)
    }
}
