import Foundation
import LogReaderCore

public struct SimulatorLogDiscovery {

    private let devicesDirectory: URL

    public static var defaultDevicesDirectory: URL {
        SimulatorLogScanner.defaultDevicesDirectory
    }

    public init(devicesDirectory: URL) {
        self.devicesDirectory = devicesDirectory
    }
}

// MARK: - LogDiscovery

extension SimulatorLogDiscovery: LogDiscovery {

    public func scan(rules: [DiscoveryRule]) -> [SimulatorDevice] {
        SimulatorLogScanner(devicesDirectory: devicesDirectory, rules: rules).scan()
    }
}
