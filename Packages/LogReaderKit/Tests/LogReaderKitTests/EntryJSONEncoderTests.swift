import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct EntryJSONEncoderTests {

    @Test func structuredEntryKeepsTheKeyOrder() async throws {
        let json = try await encode(LogFixtures.payment, number: 2)

        #expect(json == """
        {
          "number" : 2,
          "level" : "error",
          "time" : "2026-10-07T22:18:55.000Z",
          "tags" : [],
          "category" : "default",
          "source" : "Store:20",
          "message" : "Payment failed",
          "fields" : {
            "reason" : "timeout"
          }
        }
        """)
    }

    @Test func entryWithoutHeaderHasNullMetadata() async throws {
        let json = try await encode("Plain text line\nsecond line\n", number: 1)

        #expect(json == """
        {
          "number" : 1,
          "level" : null,
          "time" : null,
          "tags" : [],
          "category" : null,
          "source" : null,
          "message" : "Plain text line",
          "fields" : {
            "text" : "second line"
          }
        }
        """)
    }

    @Test func prettyJSONFieldBecomesANestedValueAndRepeatedKeysGetASuffix() async throws {
        let entry = "Request sent #network INF [api] [Net:5] 2026-10-07 22:18:54.250\n"
            + "  note: see https://example.com/a\n"
            + "  body: {\"b\":1,\"a\":[true,null,\"x/y\",1.5]}\n"
            + "  body: plain\n"
        let json = try await encode(entry, number: 7)

        #expect(json == """
        {
          "number" : 7,
          "level" : "info",
          "time" : "2026-10-07T22:18:54.250Z",
          "tags" : [
            "network"
          ],
          "category" : "api",
          "source" : "Net:5",
          "message" : "Request sent",
          "fields" : {
            "body" : {
              "a" : [
                true,
                null,
                "x/y",
                1.5
              ],
              "b" : 1
            },
            "body#2" : "plain",
            "note" : "see https://example.com/a"
          }
        }
        """)
    }

    private func encode(_ entry: String, number: Int) async throws -> String {
        var harness = SessionHarness(bookmarks: [], debounce: .milliseconds(1))
        await harness.start(with: [entry])
        let record = try #require(harness.session.record(at: 0))
        return EntryJSONEncoder.json(number: number, record: record, text: harness.session.text(of: record), profile: LogFixtures.profile)
    }

    @Test func attributeKeysFollowTheProfile() throws {
        let profile = ProfileFixtures.jsonLines
        let line = #"{"timestamp":"2026-10-07T22:18:54.000Z","level":"error","subsystem":"com.example.app","category":"network","message":"Timed out","file":"Client.swift","line":12,"process":"App"}"#
        var indexer = LogIndexer(profile: profile)
        var content = LogContent(profile: profile)
        let consumed = indexer.consume(Data((line + "\n").utf8))
        let batch = try #require(consumed)
        content.append(batch)
        let record = try #require(content.records.first)

        let json = EntryJSONEncoder.json(number: 1, record: record, text: content.text(of: record), profile: profile)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let keys = json.split(separator: "\n")
            .filter { $0.hasPrefix("  \"") }
            .compactMap { $0.split(separator: "\"").dropFirst().first.map(String.init) }

        #expect(keys == ["number", "level", "time", "subsystem", "category", "source", "process", "thread", "message", "fields"])
        #expect(object["level"] as? String == "error")
        #expect(object["subsystem"] as? String == "com.example.app")
        #expect(object["category"] as? String == "network")
        #expect(object["thread"] is NSNull)
        #expect(object["message"] as? String == "Timed out")
    }
}
