import Foundation
import LogReaderCore

public struct CompositeLogDiscovery {

    private let physicalDevices: any LogDiscovery
    private let simulators: any LogDiscovery
    private let includesPhysicalDevices: @Sendable () -> Bool

    public init(
        physicalDevices: any LogDiscovery,
        simulators: any LogDiscovery,
        includesPhysicalDevices: @escaping @Sendable () -> Bool
    ) {
        self.physicalDevices = physicalDevices
        self.simulators = simulators
        self.includesPhysicalDevices = includesPhysicalDevices
    }
}

// MARK: - LogDiscovery

extension CompositeLogDiscovery: LogDiscovery {

    public func scan(rules: [DiscoveryRule]) -> [SimulatorDevice] {
        let devices = includesPhysicalDevices() ? physicalDevices.scan(rules: rules) : []
        return devices + simulators.scan(rules: rules)
    }
}
