import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct PhysicalDeviceDiscoveryTests {

    private let runner = FakeDevicectlRunner()
    private let cacheRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("PhysicalDeviceDiscoveryTests-\(UUID().uuidString)", isDirectory: true)

    init() {
        runner.setResponse(
            DevicectlFixtures.devices([
                .init(identifier: "WATCH-1", name: "Test Watch", osVersion: "11.0", platform: "watchOS", tunnelState: "connected", transportType: "localNetwork"),
                .init(identifier: "OFFLINE-1", name: "Old Phone", osVersion: "26.1", platform: "iOS", tunnelState: "unavailable", transportType: nil),
                .init(identifier: "PHONE-1", name: "Test Phone", osVersion: "27.0.1", platform: "iOS", tunnelState: "connected", transportType: "localNetwork")
            ]),
            for: DevicectlCommand.listDevices()
        )
        runner.setResponse(
            DevicectlFixtures.apps([
                (bundleID: "com.example.store", builtByDeveloper: false),
                (bundleID: "com.example.chat", builtByDeveloper: true),
                (bundleID: "org.other.tool", builtByDeveloper: true)
            ]),
            for: DevicectlCommand.apps(device: "PHONE-1")
        )
        runner.setResponse(
            DevicectlFixtures.files([
                (relativePath: "Cache/data.sqlite", size: 4096),
                (relativePath: "Logs/notes.json", size: 10),
                (relativePath: "Logs/log-2026.11.06-08:00:00.txt", size: 1200),
                (relativePath: "Logs/log-2026.11.07-10:34:52.txt", size: 546960)
            ]),
            for: DevicectlCommand.files(device: "PHONE-1", bundleID: "com.example.chat", logsPath: DiscoveryRule.standardLogsPath)
        )
    }

    @Test func listsReachableIOSDevicesWithDeveloperAppsAndLogFiles() throws {
        defer { removeCache() }
        let devices = makeDiscovery(cacheDuration: .seconds(5)).scan(rules: [Self.rule("com.example")])

        let device = try #require(devices.first)
        let app = try #require(device.apps.first)
        let logsURL = cacheRoot.appendingPathComponent("PHONE-1/com.example.chat", isDirectory: true)
        #expect(devices.count == 1)
        #expect(device.udid == "PHONE-1")
        #expect(device.name == "Test Phone")
        #expect(device.runtime == "iOS 27.0.1")
        #expect(device.isBooted)
        #expect(device.kind == .physical(.network))
        #expect(device.folderURL == cacheRoot.appendingPathComponent("PHONE-1", isDirectory: true))
        #expect(device.apps.map(\.bundleID) == ["com.example.chat"])
        #expect(app.logsURL == logsURL)
        #expect(app.files.map(\.url.lastPathComponent) == ["log-2026.11.07-10:34:52.txt", "log-2026.11.06-08:00:00.txt"])
        #expect(app.files.map(\.url) == app.files.map { logsURL.appendingPathComponent($0.url.lastPathComponent) })
        #expect(app.files.map(\.size) == [546960, 1200])
        #expect(FileManager.default.fileExists(atPath: logsURL.path))
        #expect(runner.callCount(DevicectlFixtures.appsCommand) == 1)
    }

    @Test func deviceWithoutMatchingAppsIsHidden() {
        defer { removeCache() }

        #expect(makeDiscovery(cacheDuration: .seconds(5)).scan(rules: [Self.rule("com.missing")]).isEmpty)
    }

    @Test func resultIsCachedForTheCacheDuration() {
        defer { removeCache() }
        let discovery = makeDiscovery(cacheDuration: .seconds(60))

        let first = discovery.scan(rules: [Self.rule("com.example")])
        let second = discovery.scan(rules: [Self.rule("com.example")])

        #expect(first == second)
        #expect(runner.callCount(DevicectlFixtures.listCommand) == 1)
    }

    @Test func anotherPrefixOrAnExpiredCacheScansAgain() {
        defer { removeCache() }
        let cached = makeDiscovery(cacheDuration: .seconds(60))
        _ = cached.scan(rules: [Self.rule("com.example")])
        _ = cached.scan(rules: [Self.rule("org.other")])
        #expect(runner.callCount(DevicectlFixtures.listCommand) == 2)

        let uncached = makeDiscovery(cacheDuration: .zero)
        _ = uncached.scan(rules: [Self.rule("com.example")])
        _ = uncached.scan(rules: [Self.rule("com.example")])
        #expect(runner.callCount(DevicectlFixtures.listCommand) == 4)
    }

    @Test func failedCallsKeepThePreviousResult() {
        defer { removeCache() }
        let discovery = makeDiscovery(cacheDuration: .zero)
        let first = discovery.scan(rules: [Self.rule("com.example")])

        runner.setFailing(DevicectlFixtures.filesCommand, true)
        #expect(discovery.scan(rules: [Self.rule("com.example")]) == first)

        runner.setFailing(DevicectlFixtures.listCommand, true)
        #expect(discovery.scan(rules: [Self.rule("com.example")]) == first)
    }

    @Test func failingToolGivesNoDevices() {
        defer { removeCache() }
        runner.setFailing(DevicectlFixtures.listCommand, true)

        #expect(makeDiscovery(cacheDuration: .zero).scan(rules: [Self.rule("com.example")]).isEmpty)
    }

    @Test func emptyRulesScanNothing() {
        defer { removeCache() }

        #expect(makeDiscovery(cacheDuration: .zero).scan(rules: []).isEmpty)
        #expect(runner.calls.isEmpty)
    }

    @Test func ruleFileNamePrefixFiltersTheFiles() throws {
        defer { removeCache() }
        let rule = DiscoveryRule(bundleIDPrefix: "com.example", logsPath: DiscoveryRule.standardLogsPath, fileExtension: "json", fileNamePrefix: "")

        let devices = makeDiscovery(cacheDuration: .zero).scan(rules: [rule])

        let app = try #require(devices.first?.apps.first)
        #expect(app.files.map(\.url.lastPathComponent) == ["notes.json"])
    }

    private static func rule(_ bundleIDPrefix: String) -> DiscoveryRule {
        DiscoveryRule(bundleIDPrefix: bundleIDPrefix, logsPath: DiscoveryRule.standardLogsPath, fileExtension: "txt", fileNamePrefix: "log-")
    }

    private func makeDiscovery(cacheDuration: Duration) -> PhysicalDeviceDiscovery {
        PhysicalDeviceDiscovery(runner: runner, cacheRoot: cacheRoot, cacheDuration: cacheDuration)
    }

    private func removeCache() {
        try? FileManager.default.removeItem(at: cacheRoot)
    }
}
