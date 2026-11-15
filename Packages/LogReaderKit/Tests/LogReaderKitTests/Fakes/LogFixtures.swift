import Foundation
import LogReaderCore

struct LogFixtures {

    static let url = URL(fileURLWithPath: "/tmp/logs/log-2026.10.07-22:18:54.txt")
    static let header = "{\"v\":1,\"sep\":\"\\u001e\"}\n"
    static let socket = "Socket connected #network INF [websocket] [Sockets:10] 2026-10-07 22:18:54.000\n"
    static let payment = "Payment failed ERR [default] [Store:20] 2026-10-07 22:18:55.000\n  reason: timeout\n"
    static let debug = "Debug noise DBG [default] [Misc:30] 2026-10-07 22:18:56.000\n"
    static let sample = [socket, payment, debug]

    static let profile = ProfileFixtures.textTrailing

    private var indexer = LogIndexer(profile: ProfileFixtures.textTrailing)
    private var hasWrittenHeader = false

    mutating func batch(_ entries: [String]) -> LogBatch {
        var text = hasWrittenHeader ? "" : Self.header
        hasWrittenHeader = true
        text += entries.map { $0 + "\u{1E}" }.joined()
        guard let batch = indexer.consume(Data(text.utf8)) else {
            preconditionFailure("Fixture entries produced no batch")
        }
        return batch
    }

    static func entry(_ message: String, level: String) -> String {
        "\(message) \(level) [default] [Misc:1] 2026-10-07 22:18:54.000\n"
    }

    static func record(message: String, level: String?, tags: [String], category: String?, source: String?) -> LogRecord {
        LogRecord(
            offset: 0,
            chunk: 0,
            start: 0,
            length: 0,
            metadataRange: 0..<0,
            level: level.flatMap(profile.level(id:)),
            timestamp: 0,
            message: message,
            detailPreview: "",
            attributes: [.list(tags), category.map(AttributeValue.text) ?? .none, source.map(AttributeValue.text) ?? .none],
            isStructured: true
        )
    }

    static func device(_ udid: String, apps: [AppLogContainer]) -> SimulatorDevice {
        SimulatorDevice(
            udid: udid,
            name: "iPhone \(udid)",
            runtime: "iOS 26.0",
            isBooted: true,
            folderURL: URL(fileURLWithPath: "/devices/\(udid)", isDirectory: true),
            apps: apps,
            kind: .simulator
        )
    }

    static func app(_ bundleID: String, logsPath: String, files: [String]) -> AppLogContainer {
        let logsURL = URL(fileURLWithPath: logsPath, isDirectory: true)
        let items = files.map { name in
            LogFileItem(url: logsURL.appendingPathComponent(name), size: 1, createdAt: .distantPast)
        }
        return AppLogContainer(bundleID: bundleID, logsURL: logsURL, files: items)
    }
}
