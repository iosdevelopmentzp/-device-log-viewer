import Foundation
import LogReaderCore
import Observation

@MainActor
@Observable
public final class SidebarStore {

    public private(set) var devices: [SimulatorDevice] = []
    public private(set) var openedFiles: [URL] = []
    public var collapsedAppIDs: Set<String> = []

    @ObservationIgnored public weak var observer: (any SidebarStoreObserver)?

    @ObservationIgnored private let discovery: any LogDiscovery
    @ObservationIgnored private let scanInterval: Duration
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var rules: [DiscoveryRule]?

    public init(discovery: any LogDiscovery, scanInterval: Duration) {
        self.discovery = discovery
        self.scanInterval = scanInterval
    }

    public func start(rules: [DiscoveryRule]) {
        scanTask?.cancel()
        self.rules = rules
        let discovery = discovery
        let scanInterval = scanInterval
        scanTask = Task { [weak self] in
            while Task.isCancelled == false {
                let devices = await Task.detached(priority: .utility) {
                    discovery.scan(rules: rules)
                }.value
                guard let self else { return }
                guard Task.isCancelled == false else { return }
                update(devices)
                try? await Task.sleep(for: scanInterval)
            }
        }
    }

    public func stop() {
        scanTask?.cancel()
        rules = nil
    }

    public func rescan() {
        guard let rules else { return }
        start(rules: rules)
    }

    public func addOpenedFile(_ url: URL) {
        guard openedFiles.contains(url) == false else { return }
        openedFiles.insert(url, at: 0)
    }

    public func removeOpenedFile(_ url: URL) {
        openedFiles.removeAll { $0 == url }
    }

    public func app(containing fileURL: URL) -> AppLogContainer? {
        let directory = Self.directoryPath(of: fileURL)
        return devices
            .lazy
            .flatMap(\.apps)
            .first { Self.directoryPath(of: $0) == directory }
    }

    public func device(containing fileURL: URL) -> SimulatorDevice? {
        let directory = Self.directoryPath(of: fileURL)
        return devices.first { device in
            device.apps.contains { Self.directoryPath(of: $0) == directory }
        }
    }
}

// MARK: - Private

private extension SidebarStore {

    func update(_ newDevices: [SimulatorDevice]) {
        guard newDevices != devices else { return }
        devices = newDevices
        observer?.devicesDidChange()
    }

    static func directoryPath(of fileURL: URL) -> String {
        fileURL.deletingLastPathComponent().standardizedFileURL.path
    }

    static func directoryPath(of app: AppLogContainer) -> String {
        app.logsURL.standardizedFileURL.path
    }
}
