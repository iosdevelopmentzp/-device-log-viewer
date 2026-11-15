import Foundation
import LogReaderCore
import Synchronization

public final class PhysicalDeviceDiscovery: Sendable {

    private struct Snapshot {
        let rules: [DiscoveryRule]
        let time: ContinuousClock.Instant
        let devices: [SimulatorDevice]
    }

    private let runner: any DevicectlCommandRunning
    private let cacheRoot: URL
    private let cacheDuration: Duration
    private let snapshot = Mutex<Snapshot?>(nil)

    public static var defaultCacheRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/LogReader/Devices", isDirectory: true)
    }

    public init(runner: any DevicectlCommandRunning, cacheRoot: URL, cacheDuration: Duration) {
        self.runner = runner
        self.cacheRoot = cacheRoot
        self.cacheDuration = cacheDuration
    }
}

// MARK: - LogDiscovery

extension PhysicalDeviceDiscovery: LogDiscovery {

    public func scan(rules: [DiscoveryRule]) -> [SimulatorDevice] {
        guard rules.isEmpty == false else { return [] }
        return snapshot.withLock { snapshot in
            let previous = snapshot.flatMap { $0.rules == rules ? $0 : nil }
            if let previous, previous.time.duration(to: .now) < cacheDuration {
                return previous.devices
            }
            let devices = scanDevices(rules: rules, previous: previous?.devices ?? [])
            snapshot = Snapshot(rules: rules, time: .now, devices: devices)
            return devices
        }
    }
}

// MARK: - Private

private extension PhysicalDeviceDiscovery {

    func scanDevices(rules: [DiscoveryRule], previous: [SimulatorDevice]) -> [SimulatorDevice] {
        guard let list = try? runner.decode(DevicectlDeviceList.self, arguments: DevicectlCommand.listDevices()) else {
            return previous
        }
        return list.reachableIOSDevices
            .compactMap { entry -> SimulatorDevice? in
                do {
                    return try device(for: entry, rules: rules)
                } catch {
                    return previous.first { $0.udid == entry.identifier }
                }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func device(for entry: DevicectlDevice, rules: [DiscoveryRule]) throws -> SimulatorDevice? {
        let apps = try runner.decode(DevicectlAppList.self, arguments: DevicectlCommand.apps(device: entry.identifier))
            .developerApps(rules: rules)
            .compactMap { app -> AppLogContainer? in
                guard let rule = rules.first(where: { $0.matches(bundleID: app.bundleIdentifier) }) else { return nil }
                return try container(bundleID: app.bundleIdentifier, udid: entry.identifier, rule: rule)
            }
        guard apps.isEmpty == false else { return nil }
        return SimulatorDevice(
            udid: entry.identifier,
            name: entry.name,
            runtime: "\(entry.platform) \(entry.osVersion)",
            isBooted: true,
            folderURL: DeviceFileLocation.deviceFolderURL(in: cacheRoot, udid: entry.identifier),
            apps: apps,
            kind: .physical(entry.transport)
        )
    }

    func container(bundleID: String, udid: String, rule: DiscoveryRule) throws -> AppLogContainer {
        let logsURL = DeviceFileLocation.logsURL(in: cacheRoot, udid: udid, bundleID: bundleID)
        try? FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true)
        let arguments = DevicectlCommand.files(device: udid, bundleID: bundleID, logsPath: rule.logsPath)
        let files = try runner.decode(DevicectlFileList.self, arguments: arguments)
            .logFiles(rule: rule)
            .map { file in
                LogFileItem(
                    url: logsURL.appendingPathComponent(file.name),
                    size: file.size,
                    createdAt: file.createdAt(fileNamePrefix: rule.fileNamePrefix)
                )
            }
        return AppLogContainer(bundleID: bundleID, logsURL: logsURL, files: files)
    }
}
