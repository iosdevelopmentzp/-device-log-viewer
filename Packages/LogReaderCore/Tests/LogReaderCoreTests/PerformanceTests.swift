import Foundation
import Testing
@testable import LogReaderCore

@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOGREADER_PERF"] != nil))
struct PerformanceTests {

    enum Kind: String, CaseIterable {
        case trailing
        case leading
        case regex
        case json

        var profile: LogProfile {
            switch self {
            case .trailing: ProfileFixtures.textTrailing
            case .leading: ProfileFixtures.textLeading
            case .regex: ProfileFixtures.regex
            case .json: ProfileFixtures.jsonLines
            }
        }
    }

    @Test(arguments: Kind.allCases)
    func indexAndSearchLargeFile(kind: Kind) throws {
        let data = Self.makeLargeLog(kind: kind, targetBytes: 50 * 1_024 * 1_024)
        let profile = kind.profile

        let clock = ContinuousClock()
        var indexer = LogIndexer(profile: profile)
        var batch: LogBatch?
        let indexDuration = clock.measure {
            batch = indexer.consume(data)
        }
        var content = LogContent(profile: profile)
        content.append(try #require(batch))

        var filter = LogFilter.all
        filter.text = "needle-not-present"
        var matches: [Int] = []
        let searchDuration = try clock.measure {
            matches = try LogFilterEngine.indices(in: content, range: 0..<content.records.count, filter: filter)
        }

        filter.text = "привет"
        let unicodeDuration = try clock.measure {
            _ = try LogFilterEngine.indices(in: content, range: 0..<content.records.count, filter: filter)
        }

        filter.text = "\\bcyrillic\\b"
        filter.isRegex = true
        let regexDuration = try clock.measure {
            _ = try LogFilterEngine.indices(in: content, range: 0..<content.records.count, filter: filter)
        }

        filter = .all
        filter.facets[.level] = .only(["error"])
        filter.facets[.attribute(kind == .regex ? "module" : "category")] = .only(["default"])
        let facetDuration = try clock.measure {
            _ = try LogFilterEngine.indices(in: content, range: 0..<content.records.count, filter: filter)
        }

        print("PERF kind=\(kind.rawValue) bytes=\(data.count) records=\(content.records.count) structured=\(content.records.filter(\.isStructured).count) index=\(indexDuration) asciiSearch=\(searchDuration) unicodeSearch=\(unicodeDuration) regexSearch=\(regexDuration) facets=\(facetDuration)")
        #expect(matches.isEmpty)
        #expect(content.records.allSatisfy { $0.isStructured })
        #expect(indexDuration < .seconds(1))
        #expect(regexDuration < .seconds(2))
    }

    static func makeLargeLog(kind: Kind, targetBytes: Int) -> Data {
        var text = kind == .trailing ? ProfileFixtures.header : ""
        text.reserveCapacity(targetBytes + 64 * 1_024)
        let json = "{\"type\":\"callEnd\",\"data\":{" + (0..<600).map { "\"key\($0)\":\"value \($0) with some text\"" }.joined(separator: ",") + "}}"
        var index = 0
        while text.utf8.count < targetBytes {
            let second = String(format: "%02d", index % 60)
            let isPayload = index % 50 == 0
            switch kind {
            case .trailing:
                text += isPayload
                    ? "on event user/\(index)/event DBG [websocket] [Sockets:300] 2026-10-07 22:18:\(second).123\n  payload: \(json)\n\u{1E}"
                    : "[NETWORK REQUEST] #network INF [default] [ApiService:229] 2026-10-07 22:18:\(second).456\n  URL: /v1/social/favorites/listBy/\(index)\n  method: GET\n\u{1E}"
            case .leading:
                text += isPayload
                    ? "2026-10-07 22:18:\(second).123 [DEBUG] [websocket] on event user/\(index)/event payload=\(json)\n"
                    : "2026-10-07 22:18:\(second).456 [INFO] [default] #network [NETWORK REQUEST] URL /v1/social/favorites/listBy/\(index) method GET\n"
            case .regex:
                text += isPayload
                    ? "22:18:\(second) D websocket - on event user/\(index)/event payload=\(json)\n"
                    : "22:18:\(second) I default - [NETWORK REQUEST] URL /v1/social/favorites/listBy/\(index) method GET\n"
            case .json:
                text += isPayload
                    ? "{\"timestamp\":\"2026-10-07T22:18:\(second).123Z\",\"level\":\"debug\",\"category\":\"websocket\",\"message\":\"on event user/\(index)/event\",\"payload\":\(json)}\n"
                    : "{\"timestamp\":\"2026-10-07T22:18:\(second).456Z\",\"level\":\"info\",\"category\":\"default\",\"message\":\"[NETWORK REQUEST]\",\"URL\":\"/v1/social/favorites/listBy/\(index)\",\"method\":\"GET\"}\n"
            }
            index += 1
        }
        return Data(text.utf8)
    }
}
