import Foundation
import LogReaderCore
import Testing
@testable import LogReaderKit

struct NewestFilePolicyTests {

    private let logsPath = "/tmp/device/app/Logs"

    @Test func latestFilesMapsEachAppToItsNewestFile() {
        let devices = [
            LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: ["new.txt", "old.txt"])]),
            LogFixtures.device("B", apps: [LogFixtures.app("com.example.b", logsPath: "/tmp/b/Logs", files: [])])
        ]

        #expect(NewestFilePolicy.latestFiles(in: devices) == [logsPath: logsPath + "/new.txt"])
    }

    @Test func opensTheNewFileWhenTheCurrentFileWasTheNewest() {
        let devices = [LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: ["new.txt", "old.txt"])])]
        let current = URL(fileURLWithPath: logsPath + "/old.txt")

        let result = NewestFilePolicy.fileToOpen(
            current: current,
            previousLatest: [logsPath: current.path],
            devices: devices
        )

        #expect(result == URL(fileURLWithPath: logsPath + "/new.txt"))
    }

    @Test func keepsAnOlderFileTheUserChose() {
        let devices = [LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: ["newest.txt", "new.txt", "old.txt"])])]
        let current = URL(fileURLWithPath: logsPath + "/old.txt")

        let result = NewestFilePolicy.fileToOpen(
            current: current,
            previousLatest: [logsPath: logsPath + "/new.txt"],
            devices: devices
        )

        #expect(result == nil)
    }

    @Test func doesNothingWhenTheCurrentFileIsStillTheNewest() {
        let devices = [LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: ["new.txt"])])]
        let current = URL(fileURLWithPath: logsPath + "/new.txt")

        let result = NewestFilePolicy.fileToOpen(
            current: current,
            previousLatest: [logsPath: current.path],
            devices: devices
        )

        #expect(result == nil)
    }

    @Test func doesNothingForAFileOutsideTheSimulators() {
        let devices = [LogFixtures.device("A", apps: [LogFixtures.app("com.example.a", logsPath: logsPath, files: ["new.txt"])])]
        let current = URL(fileURLWithPath: "/Users/me/Downloads/log.txt")

        let result = NewestFilePolicy.fileToOpen(
            current: current,
            previousLatest: [logsPath: current.path],
            devices: devices
        )

        #expect(result == nil)
    }
}
