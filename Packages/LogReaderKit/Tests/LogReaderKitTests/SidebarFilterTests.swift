import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct SidebarFilterTests {

    private let devices = [
        LogFixtures.device("A", apps: [
            LogFixtures.app("com.example.app", logsPath: "/tmp/a/app/Logs", files: ["log-2.txt", "log-1.txt"]),
            LogFixtures.app("com.example.widget", logsPath: "/tmp/a/widget/Logs", files: ["widget-1.txt"])
        ]),
        SimulatorDevice(
            udid: "B",
            name: "iPad B",
            runtime: "iOS 18.0",
            isBooted: false,
            folderURL: URL(fileURLWithPath: "/devices/B", isDirectory: true),
            apps: [LogFixtures.app("com.example.app", logsPath: "/tmp/b/app/Logs", files: ["log-3.txt"])],
            kind: .simulator
        )
    ]

    @Test func emptyQueryReturnsTheInput() {
        #expect(SidebarFilter.apply(devices, query: "  ", bootedOnly: false, contentResults: nil) == devices)
    }

    @Test func fileNameMatchKeepsOnlyThatFile() {
        let result = SidebarFilter.apply(devices, query: "log-1", bootedOnly: false, contentResults: nil)

        #expect(result.map(\.udid) == ["A"])
        #expect(result[0].apps.map(\.bundleID) == ["com.example.app"])
        #expect(result[0].apps[0].files.map(\.url.lastPathComponent) == ["log-1.txt"])
    }

    @Test func bundleIDMatchKeepsAllFilesOfTheApp() {
        let result = SidebarFilter.apply(devices, query: "widget", bootedOnly: false, contentResults: nil)

        #expect(result.map(\.udid) == ["A"])
        #expect(result[0].apps == [devices[0].apps[1]])
    }

    @Test func deviceNameMatchKeepsEverythingUnderTheDevice() {
        let result = SidebarFilter.apply(devices, query: "ipad", bootedOnly: false, contentResults: nil)

        #expect(result == [devices[1]])
    }

    @Test func runtimeMatchKeepsEverythingUnderTheDevice() {
        let result = SidebarFilter.apply(devices, query: "iOS 18", bootedOnly: false, contentResults: nil)

        #expect(result == [devices[1]])
    }

    @Test func matchingIgnoresCaseAndSurroundingSpaces() {
        let result = SidebarFilter.apply(devices, query: " LOG-3.TXT ", bootedOnly: false, contentResults: nil)

        #expect(result == [devices[1]])
    }

    @Test func bootedOnlyDropsAStoppedDevice() {
        #expect(SidebarFilter.apply(devices, query: "", bootedOnly: true, contentResults: nil) == [devices[0]])
        #expect(SidebarFilter.apply(devices, query: "log-3", bootedOnly: true, contentResults: nil).isEmpty)
    }

    @Test func deviceWithoutRemainingFilesIsDropped() {
        let result = SidebarFilter.apply(devices, query: "log-2", bootedOnly: false, contentResults: nil)

        #expect(result.map(\.udid) == ["A"])
        #expect(SidebarFilter.apply(devices, query: "missing", bootedOnly: false, contentResults: nil).isEmpty)
    }

    @Test func contentResultsKeepOnlyMatchingOrSkippedFiles() {
        let results: [String: FileSearchResult] = [
            "/tmp/a/app/Logs/log-2.txt": .count(3),
            "/tmp/a/app/Logs/log-1.txt": .count(0),
            "/tmp/a/widget/Logs/widget-1.txt": .count(0),
            "/tmp/b/app/Logs/log-3.txt": .skipped
        ]

        let result = SidebarFilter.apply(devices, query: "ignored", bootedOnly: false, contentResults: results)

        #expect(result.map(\.udid) == ["A", "B"])
        #expect(result[0].apps.map(\.bundleID) == ["com.example.app"])
        #expect(result[0].apps[0].files.map(\.url.lastPathComponent) == ["log-2.txt"])
        #expect(result[1] == devices[1])
    }

    @Test func contentModeIgnoresNameMatches() {
        let result = SidebarFilter.apply(devices, query: "ipad", bootedOnly: false, contentResults: [:])

        #expect(result.isEmpty)
    }

    @Test func contentModeAppliesBootedOnly() {
        let results: [String: FileSearchResult] = ["/tmp/b/app/Logs/log-3.txt": .count(1)]

        #expect(SidebarFilter.apply(devices, query: "x", bootedOnly: true, contentResults: results).isEmpty)
        #expect(SidebarFilter.apply(devices, query: "x", bootedOnly: false, contentResults: results) == [devices[1]])
    }
}
