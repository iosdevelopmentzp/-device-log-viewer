import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct CompositeLogDiscoveryTests {

    private let physical = FakeLogDiscovery(devices: [LogFixtures.device("PHONE", apps: [])])
    private let simulators = FakeLogDiscovery(devices: [LogFixtures.device("SIM", apps: [])])
    private let flag = SharedFlag(isOn: true)
    private let rules = [DiscoveryRule(bundleIDPrefix: "com.example", logsPath: "Logs", fileExtension: "txt", fileNamePrefix: "log-")]

    @Test func physicalDevicesComeFirst() {
        let devices = makeDiscovery().scan(rules: rules)

        #expect(devices.map(\.udid) == ["PHONE", "SIM"])
        #expect(physical.scannedRules == [rules])
        #expect(simulators.scannedRules == [rules])
    }

    @Test func switchedOffSettingSkipsPhysicalDevices() {
        flag.set(false)

        let devices = makeDiscovery().scan(rules: rules)

        #expect(devices.map(\.udid) == ["SIM"])
        #expect(physical.scannedRules.isEmpty)
    }

    private func makeDiscovery() -> CompositeLogDiscovery {
        let flag = flag
        return CompositeLogDiscovery(physicalDevices: physical, simulators: simulators, includesPhysicalDevices: { flag.isOn })
    }
}
