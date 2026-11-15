import Foundation
import LogReaderCore

public protocol LogDiscovery: Sendable {
    func scan(rules: [DiscoveryRule]) -> [SimulatorDevice]
}
