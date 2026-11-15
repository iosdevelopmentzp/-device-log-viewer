import Foundation
import LogReaderCore

public enum SidebarFilter {

    public static func apply(
        _ devices: [SimulatorDevice],
        query: String,
        bootedOnly: Bool,
        contentResults: [String: FileSearchResult]?
    ) -> [SimulatorDevice] {
        let candidates = bootedOnly ? devices.filter(\.isBooted) : devices
        if let contentResults {
            return candidates.compactMap { filtered($0, contentResults: contentResults) }
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.isEmpty == false else { return candidates }
        return candidates.compactMap { filtered($0, needle: needle) }
    }
}

// MARK: - Private

private extension SidebarFilter {

    static func filtered(_ device: SimulatorDevice, needle: String) -> SimulatorDevice? {
        guard matches(device.name, needle) == false, matches(device.runtime, needle) == false else { return device }
        return Self.device(device, apps: device.apps.compactMap { filtered($0, needle: needle) })
    }

    static func filtered(_ app: AppLogContainer, needle: String) -> AppLogContainer? {
        guard matches(app.bundleID, needle) == false else { return app }
        return Self.app(app, files: app.files.filter { matches($0.url.lastPathComponent, needle) })
    }

    static func filtered(_ device: SimulatorDevice, contentResults: [String: FileSearchResult]) -> SimulatorDevice? {
        Self.device(device, apps: device.apps.compactMap { filtered($0, contentResults: contentResults) })
    }

    static func filtered(_ app: AppLogContainer, contentResults: [String: FileSearchResult]) -> AppLogContainer? {
        Self.app(app, files: app.files.filter { isContentMatch(contentResults[$0.url.path]) })
    }

    static func isContentMatch(_ result: FileSearchResult?) -> Bool {
        switch result {
        case let .count(count): count > 0
        case .skipped: true
        case nil: false
        }
    }

    static func matches(_ text: String, _ needle: String) -> Bool {
        text.range(of: needle, options: .caseInsensitive) != nil
    }

    static func device(_ device: SimulatorDevice, apps: [AppLogContainer]) -> SimulatorDevice? {
        guard apps.isEmpty == false else { return nil }
        return SimulatorDevice(
            udid: device.udid,
            name: device.name,
            runtime: device.runtime,
            isBooted: device.isBooted,
            folderURL: device.folderURL,
            apps: apps,
            kind: device.kind
        )
    }

    static func app(_ app: AppLogContainer, files: [LogFileItem]) -> AppLogContainer? {
        guard files.isEmpty == false else { return nil }
        return AppLogContainer(bundleID: app.bundleID, logsURL: app.logsURL, files: files)
    }
}
