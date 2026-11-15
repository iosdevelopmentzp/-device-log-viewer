import Foundation
import LogReaderCore
import LogReaderKit
import Synchronization

final class FakeLogDiscovery: LogDiscovery {

    private let state: Mutex<(devices: [SimulatorDevice], rules: [[DiscoveryRule]])>

    var scannedRules: [[DiscoveryRule]] {
        state.withLock { $0.rules }
    }

    init(devices: [SimulatorDevice]) {
        self.state = Mutex((devices: devices, rules: []))
    }

    func setDevices(_ devices: [SimulatorDevice]) {
        state.withLock { $0.devices = devices }
    }

    func scan(rules: [DiscoveryRule]) -> [SimulatorDevice] {
        state.withLock { state in
            state.rules.append(rules)
            return state.devices
        }
    }
}
