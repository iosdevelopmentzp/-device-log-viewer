import Foundation

public struct SimulatorLogScanner: Sendable {

    public let devicesDirectory: URL
    public let rules: [DiscoveryRule]

    private static let bootedState = 3
    private static let containerMetadataFile = ".com.apple.mobile_container_manager.metadata.plist"

    public static var defaultDevicesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
    }

    public init(devicesDirectory: URL, rules: [DiscoveryRule]) {
        self.devicesDirectory = devicesDirectory
        self.rules = rules
    }

    public static func logFiles(in directory: URL, rule: DiscoveryRule) -> [LogFileItem] {
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        )) ?? []
        return urls
            .compactMap { url -> LogFileItem? in
                guard rule.matches(fileName: url.lastPathComponent),
                      let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
                return LogFileItem(
                    url: url,
                    size: Int64(values.fileSize ?? 0),
                    createdAt: values.creationDate ?? .distantPast
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func scan() -> [SimulatorDevice] {
        guard rules.isEmpty == false else { return [] }
        let deviceURLs = (try? FileManager.default.contentsOfDirectory(
            at: devicesDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        return deviceURLs
            .compactMap(device(at:))
            .sorted { lhs, rhs in
                guard lhs.isBooted == rhs.isBooted else { return lhs.isBooted }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

// MARK: - Private

private extension SimulatorLogScanner {

    func device(at url: URL) -> SimulatorDevice? {
        guard let info = plist(at: url.appendingPathComponent("device.plist")),
              let name = info["name"] as? String else { return nil }
        let apps = appContainers(in: url.appendingPathComponent("data/Containers/Data/Application", isDirectory: true))
        guard apps.isEmpty == false else { return nil }
        return SimulatorDevice(
            udid: url.lastPathComponent,
            name: name,
            runtime: Self.prettyRuntime(info["runtime"] as? String),
            isBooted: (info["state"] as? Int) == Self.bootedState,
            folderURL: url,
            apps: apps,
            kind: .simulator
        )
    }

    func appContainers(in directory: URL) -> [AppLogContainer] {
        let containerURLs = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        return containerURLs
            .compactMap { containerURL -> AppLogContainer? in
                let metadata = plist(at: containerURL.appendingPathComponent(Self.containerMetadataFile))
                guard let bundleID = metadata?["MCMMetadataIdentifier"] as? String else { return nil }
                guard let rule = rules.first(where: { $0.matches(bundleID: bundleID) }) else { return nil }
                let logsURL = containerURL.appendingPathComponent(rule.logsPath, isDirectory: true)
                guard FileManager.default.fileExists(atPath: logsURL.path) else { return nil }
                return AppLogContainer(
                    bundleID: bundleID,
                    logsURL: logsURL,
                    files: Self.logFiles(in: logsURL, rule: rule)
                )
            }
            .sorted { $0.bundleID < $1.bundleID }
    }

    func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    static func prettyRuntime(_ identifier: String?) -> String {
        guard let identifier, let name = identifier.split(separator: ".").last else { return "" }
        let parts = name.split(separator: "-")
        guard let platform = parts.first else { return String(name) }
        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }
}
