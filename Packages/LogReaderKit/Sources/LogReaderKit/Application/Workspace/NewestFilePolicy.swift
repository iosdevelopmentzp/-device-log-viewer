import Foundation
import LogReaderCore

public enum NewestFilePolicy {

    public static func latestFiles(in devices: [SimulatorDevice]) -> [String: String] {
        Dictionary(
            devices
                .flatMap(\.apps)
                .compactMap { app in app.files.first.map { (app.id, $0.id) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public static func fileToOpen(current: URL, previousLatest: [String: String], devices: [SimulatorDevice]) -> URL? {
        let directory = current.deletingLastPathComponent().standardizedFileURL.path
        let app = devices
            .lazy
            .flatMap(\.apps)
            .first { $0.logsURL.standardizedFileURL.path == directory }
        guard let app, let newest = app.files.first else { return nil }
        guard newest.id != current.path, previousLatest[app.id] == current.path else { return nil }
        return newest.url
    }
}
