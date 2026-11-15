import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

@MainActor
struct SidebarStoreTests {

    private let rules = [
        DiscoveryRule(bundleIDPrefix: "com.example", logsPath: DiscoveryRule.standardLogsPath, fileExtension: "txt", fileNamePrefix: "log-")
    ]
    private let devices = [
        LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: "/tmp/a/Logs", files: ["log.txt"])])
    ]

    @Test func notifiesOnlyWhenDevicesDiffer() async {
        let discovery = FakeLogDiscovery(devices: devices)
        let store = SidebarStore(discovery: discovery, scanInterval: .milliseconds(5))
        let observer = FakeSidebarStoreObserver()
        store.observer = observer

        store.start(rules: rules)
        await Eventually.wait { discovery.scannedRules.count >= 3 }

        #expect(store.devices == devices)
        #expect(observer.changeCount == 1)
        #expect(discovery.scannedRules.allSatisfy { $0 == rules })

        discovery.setDevices([])
        await Eventually.wait { store.devices.isEmpty }
        store.stop()

        #expect(observer.changeCount == 2)
    }

    @Test func findsTheAppAndTheDeviceOfAFile() async {
        let discovery = FakeLogDiscovery(devices: devices)
        let store = SidebarStore(discovery: discovery, scanInterval: .seconds(10))
        store.start(rules: [])
        await Eventually.wait { store.devices.isEmpty == false }
        store.stop()

        let file = URL(fileURLWithPath: "/tmp/a/Logs/../Logs/log.txt")

        #expect(store.app(containing: file)?.bundleID == "com.example.a")
        #expect(store.device(containing: file)?.udid == "A")
        #expect(store.app(containing: URL(fileURLWithPath: "/tmp/b/log.txt")) == nil)
    }

    @Test func openedFilesAreUniqueAndNewestFirst() {
        let store = SidebarStore(discovery: FakeLogDiscovery(devices: []), scanInterval: .seconds(10))
        let first = URL(fileURLWithPath: "/tmp/1.txt")
        let second = URL(fileURLWithPath: "/tmp/2.txt")

        store.addOpenedFile(first)
        store.addOpenedFile(second)
        store.addOpenedFile(first)
        #expect(store.openedFiles == [second, first])

        store.removeOpenedFile(second)
        #expect(store.openedFiles == [first])
    }

    @Test func rescanCallsDiscoveryAgain() async {
        let discovery = FakeLogDiscovery(devices: devices)
        let store = SidebarStore(discovery: discovery, scanInterval: .seconds(10))
        store.start(rules: rules)
        await Eventually.wait { discovery.scannedRules.count == 1 }

        store.rescan()
        await Eventually.wait { discovery.scannedRules.count == 2 }
        store.stop()

        #expect(discovery.scannedRules == [rules, rules])
    }

    @Test func rescanDoesNothingBeforeStart() async {
        let discovery = FakeLogDiscovery(devices: devices)
        let store = SidebarStore(discovery: discovery, scanInterval: .seconds(10))

        store.rescan()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(discovery.scannedRules.isEmpty)
    }
}
